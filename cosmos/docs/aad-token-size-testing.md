# Testing the Cosmos DB backend with large AAD (Entra) tokens

## Purpose

A backend change (CosmosDB PR 2386646) makes the RNTBD incoming request header + metadata limit configurable (default
16000 bytes, to be raised to ~65K). The Entra token travels in the `Authorization` header of every request, so a large
token directly affects that limit. This runbook finds the token size at which backend throughput drops or latency rises
(token sizes ~2K to ~60K) using this YCSB based framework.

Real Entra tokens stop growing at about 10K (the `groups` claim is capped at ~200 groups), so larger tokens are minted
**test-only** tokens, signed with a test key that a test federation is configured to trust.

## Architecture

| Component | Role |
| --- | --- |
| `cosmos/tools/aad-token-minter/mint_aad_tokens.py` | Mints tokens of a target size (number of GUIDs in `groups`), writes `tokens.txt`, `jwks.json`, `signing-key.pem`. |
| Test federation (CosmosDB repo) | Trusts `jwks.json` (naming config `aadPublicKeys`), the tenant (`trustedAadTenants`) and the audience; validates the tokens. |
| Blob + SAS URL | Delivers the tokens file to the benchmark VMs (`aadTokenFileUrl`). |
| `cosmos/infra/azuredeploy.json` | New optional parameters `aadTokenFileUrl`, `aadTokenMode`, `managedIdentityName`, `managedIdentityClientId`, `metadataOperation`, `metadataPercentage`; passed to the VMs as `AAD_TOKEN_FILE_URL`, `AAD_TOKEN_MODE`, `MANAGED_IDENTITY_CLIENT_ID`, `METADATA_OPERATION`, `METADATA_PERCENTAGE`. |
| `cosmos/scripts/custom-script.sh` | Downloads the tokens file to `/tmp/aad-tokens.txt` and passes `aadTokenFile`, `aadTokenMode`, `managedIdentityClientId`, `metadataOperation`, `metadataPercentage` to `azurecosmos-run.sh`. |
| `cosmos/scripts/azurecosmos-run.sh` | Writes `azurecosmos.aadTokenFile`, `azurecosmos.aadTokenMode`, `azurecosmos.managedIdentityClientId`, `azurecosmos.metadataOperation`, `azurecosmos.metadataPercentage` into `azurecosmos.properties`. |
| YCSB `azurecosmos` binding (**Azure/YCSB repo**) | Presents the tokens to Cosmos DB. Needs `cosmos/tools/ycsb-patches/aad-credential-support.patch` (not yet in Azure/YCSB). |
| Cosmos DB Java SDK -> gateway / backend | Sends `Authorization: type=aad&ver=1.0&sig=<token>` (URL encoded) on every request. |

Key facts (verified against the CosmosDB repo and the Java SDK 4.67.0 used by Azure/YCSB):

- The Java SDK builds the header with `URLEncoder.encode("type=aad&ver=1.0&sig=" + token, "UTF-8")`
  (`AadTokenAuthorizationHelper`). A JWT only contains `A-Za-z0-9-_.`, so the header is exactly **token length + 31**
  characters. The minter prints both.
- Direct mode: address resolution, partition key ranges and the database account are always read from the gateway over
  HTTPS (with the token); point reads/writes go over RNTBD to the backend replica, which authenticates AAD tokens in
  `AADTokenBackendAuthenticatorWrapper` using the tenant's `AadAuthenticator`. See
  [Where metadata requests are served](#where-metadata-requests-are-served) for `readAllDatabases`/`readAllContainers`.
- The gateway (`Authorizer.AuthorizeRequestAsync`) rejects an `Authorization` header longer than 16384 characters, or
  65536 when `use64KBTokenBufferSizeLimit` is true.

## Where metadata requests are served

Findings from the CosmosDB repo and from the Java SDK 4.67.0 that Azure/YCSB builds against. **The assumption "metadata
requests always go to the gateway, even in direct mode" does not hold for `readAllDatabases`/`readAllContainers` in this
SDK version.**

### In the Java SDK (4.67.0, decompiled `RxDocumentClientImpl.getStoreProxy`)

| Request | Direct mode (`useGateway=false`) | Gateway mode (`useGateway=true`) |
| --- | --- | --- |
| `client.readAllDatabases()` (ReadFeed, Database) | `ServerStoreModel` -> `StoreClient`: a **master resource**, sent over **RNTBD** to a master partition replica (UNVERIFIED end to end; read from bytecode: only requests with `useGatewayMode` set, Offer, ClientEncryptionKey, PartitionKeyRange, scripts, single-collection read, and create/replace/delete of databases/collections are routed to the gateway store model, and `useGatewayMode` is only set for change feed and query plan requests) | HTTPS GET `/dbs` to the gateway |
| `database.readAllContainers()` (ReadFeed, DocumentCollection) | same as above | HTTPS GET `/dbs/{db}/colls` to the gateway |
| Database account read, address (`/addresses`) and partition key range reads | HTTPS to the gateway (always) | HTTPS to the gateway |

In direct mode the master partition addresses are first resolved through the gateway (`GatewayAddressCache`, then
cached), so after warm-up a direct-mode metadata load hits the **backend master partition over RNTBD** and barely touches
the gateway. To stress the **gateway** with metadata requests use `useGateway=true`.

### In the CosmosDB gateway (`Product\Cosmos\RoutingGateway\Runtime`) - for gateway mode and address/PK range requests

1. HTTP listener limits. Kestrel (`CosmosKestrelHttpRuntime`, used by `CosmosDBHost`) is configured with
   `MaxRequestHeadersTotalSize = 100 KB`, `MaxRequestLineSize = 32 KB`, 1024 headers, so a 60K header fits. Http.sys
   based nodes use the registry values `MaxFieldLength = 65534` and `MaxRequestBytes = 131072` set by
   `ConfigureHttpSettings.ps1` / `ConfigureAndRestartHttp.ps1` (65534 is also the maximum http.sys accepts for one header
   field, so a header cannot exceed 65534). UNVERIFIED: which of these two hosting stacks serves the gateway role on the
   test federation, and that those scripts ran on its nodes.
2. `Authorizer.AuthorizeRequestAsync` throws `UnauthorizedException` ("The request contains suspiciously large auth header
   size greater than N") when the **URL encoded** header string is longer than `Constants.Max16KBTokenBufferSize` (16384)
   or, if the config `use64KBTokenBufferSizeLimit` is true, `Constants.Max64KBTokenBufferSize` (65536). The config key is
   `FederationConfiguration.ConfigurationProperties.Use64KBTokenBufferSizeLimit` (`"use64KBTokenBufferSizeLimit"`), a
   federation level naming config, read through the account configuration reader (UNVERIFIED how the account reader falls
   back to the federation value). **This must be true for any token above ~16353 characters** (16384 - 31), on the gateway
   even if only the backend limit is the subject of the test.
3. Authentication (`Authorizer.AuthorizeRequestByTokenAsync`, AAD branch): `AadAuthenticator`/MISE token validation
   (signature, claims including the `groups` array), then RBAC through `AadAuthorizationCache`. For
   `DatabaseAccount`, `Address`, `Database`, `Collection`, `ClientEncryptionKey` and `PartitionKeyRange` requests
   (`RbacAuthorizationHelper.IsMetadataResource`) the **gateway itself** checks the role action
   `AccountActions.ReadMetadata` (cached by principal, action and resource); data requests are let through
   ("Allow all supported data requests") and are authorized by the backend.
4. Forwarding to the backend: after authorization `GatewayResourceFeedRequestHandler` builds a `DocumentServiceRequest`
   and calls `DatabaseAccountRequestProcessor.ProcessMessageWithGatewayResponseAsync`; for collection feeds the default
   branch calls `ApplicationStoreClient.ProcessMessageAsync` (`RoutingGatewayStoreClient`), which is created with an
   `AuthorizationTokenProvider` over the federation/system keys and, when `EnableRntbdChannel` is true, sends over RNTBD to
   the master partition (otherwise a fallback client; UNVERIFIED which transport the test federation uses). This suggests
   that the **gateway -> backend leg uses system key signing and does not forward the large AAD token** (UNVERIFIED), so a
   gateway-mode metadata load stresses the gateway receive/auth path (Kestrel or http.sys header parsing, the
   `Authorizer` size check, token validation, the RBAC cache) and **not** the RNTBD header limit.

### Which size stresses which component

| Scenario | Token goes through | Limits involved |
| --- | --- | --- |
| Direct, point read (`workloadc`) | RNTBD request header to the backend replica | `rntbdIncomingRequestMaxMetadataSize` (backend) |
| Direct, `metadataOperation=*` | RNTBD request header to a master partition replica (after warm-up) | same backend limit; the gateway is only used for addresses/PK ranges |
| Gateway mode, `metadataOperation=*` | HTTPS header to the gateway, then gateway-side auth | HTTP listener header limits, `use64KBTokenBufferSizeLimit`; backend only sees gateway-signed requests (UNVERIFIED) |
| Any mode, first requests | HTTPS to the gateway (database account, addresses, PK ranges) | `use64KBTokenBufferSizeLimit` and HTTP listener limits |

Run both variants (`useGateway=false` and `true`) with the same token files to cover both components.

## Metadata-heavy load

> **NOISY-NEIGHBOR WARNING.** The larger header limit is a **federation level** setting
> (`use64KBTokenBufferSizeLimit`, and the backend limit in PR 2386646) and can easily cause noisy-neighbor issues:
> large tokens and a high request rate make the gateway and backend spend CPU and memory on every request, for every
> account on the federation. Run this only on an **isolated test account in an isolated test federation**, never on a
> shared or production federation, always with a **fixed `targetOperationsPerSecond`**, and ramp up in steps.

### What it does

The YCSB binding (patch in `cosmos/tools/ycsb-patches`) can execute a metadata request instead of the point read:

- `metadataOperation=listDatabases`: `client.readAllDatabases()`, every page iterated.
- `metadataOperation=listContainers`: `database.readAllContainers()` on `azurecosmos.databaseName` (`ycsb`), every page
  iterated.
- `metadataOperation=mixed`: randomly one of the two.
- `metadataPercentage` (0-100, default 100): share of YCSB `read()` calls that run the metadata operation. With
  `workloadc` and 100 the load is 100% metadata; use 50 for a metadata/data mix.

### Configure

Deploy as in the [Runbook](#runbook) below (steps 1-5), with these parameters:

| Parameter | Value |
| --- | --- |
| `workloadType` | `workloadc` |
| `metadataOperation` | `listContainers` (cheapest and stable: the `ycsb` database has one container) |
| `metadataPercentage` | `100` (or a mix) |
| `useGateway` | `false` to load the backend master partition over RNTBD, `true` to load the gateway |
| `targetOperationsPerSecond` | low and fixed, see below |
| `skipLoadPhase` | `true` (metadata operations do not need loaded data; the account only needs the database and container) |

### How it differs from point reads

- Responses are tiny and cheap to serve, and no partition/data path is involved, so the request rate a given token size
  can sustain is far higher than for point reads and CPU is dominated by header receive, token validation and RBAC.
- YCSB reports these operations as `READ` (the operation is replaced inside `read()`); with 100% metadata, `READ` latency
  is the metadata latency. With a mix the two are not separated in the YCSB output; the optional Application Insights
  metrics have separate `Metadata Successful/Unsuccessful Operations` and `Metadata Successful Latency`.
- Failures (for example 403 from `ReadMetadata` RBAC, or 401 from a rejected header size) are logged with the
  `METADATA_EXCEPTION` marker and return an error status; point read failures keep returning `NOT_FOUND`.
- RBAC: the principal needs the metadata read action (`AccountActions.ReadMetadata`); UNVERIFIED how it is granted to the
  fake principal / `--role-group` on the test federation.
- Master partition operations are not partitioned and not charged like data reads (UNVERIFIED RU/throttling behaviour for
  `ReadFeed` on databases/collections); watch for 429s and gateway throttling.

### Rate cap and stepped ramp

1. Start at the **lowest** token size (2K) and a very low rate (for example 100 ops/s total across all VMs and threads;
   `targetOperationsPerSecond` is per YCSB process, so divide by `vmCount`).
2. Hold each step at least 5 minutes, watch the gateway and backend CPU, memory and error rates, then double the rate
   (100, 200, 500, 1000, 2000, ...). Record where latency or errors start to rise at the 2K baseline; use a rate
   **below that knee** (for example 50%) as the fixed rate for all token sizes.
3. Then step the token size at that fixed rate: 2K, 4K, 8K, 16K, 24K, 32K, 48K, 60K.
4. Never raise rate and token size in the same step.

### Stop criteria (stop the run and lower the rate immediately)

- Gateway or backend CPU above 70% sustained on any node of the test federation, or memory/GC pressure rising run over run.
- Any increase in latency or errors of **other** accounts on the same federation, or any alert on the federation.
- More than 1% non-2xx responses other than the expected rejection test, or 429s.
- Gateway or replica restarts, connection resets or health probe failures.
- The planned time box is over (keep each step to minutes, not hours; `ycsbOperationCount` large only with a cap).

Reset `use64KBTokenBufferSizeLimit` and the backend limit to their defaults when the test is finished.

## Runbook

### 0. Prerequisites

- A test federation with the backend build containing PR 2386646, and a Cosmos DB account on it with a `ycsb` database
  and `usertable` container (or let a key-based run create/load them, step 5).
- Maven/JDK are only needed if you want to rebuild the YCSB binding yourself; the VMs build it from the YCSB repo.

### 1. Mint tokens

```powershell
cd cosmos\tools\aad-token-minter
pip install -r requirements.txt
python mint_aad_tokens.py --audience https://<globalAccountName>.<dns-zone> --tenant-id <tenantGuid> `
    --role-group <groupGuid> --count 100 `
    --target-size-bytes 2048 4096 8192 16384 24576 32768 49152 61440 --out tokens.txt
```

- `--tenant-id` is also used as the issuer GUID (`https://sts.fake-windows.net/<guid>/`). The backend validates the
  **issuer GUID** against the trusted tenants (`AadAuthenticator.CustomIssuerValidator`), so both must be a trusted
  tenant.
- Claims emitted: `aud`, `iss`, `iat`, `nbf`, `exp` (default 72 h), `tid`, `oid`, `scp=user_impersonation` (or
  `idtyp=app` with `--service-principal`), `uti`, `groups` (JSON array of random GUIDs; the size knob) and, to hit the
  size exactly, a small `pad` claim. All tokens of one size are distinct (random groups and `uti`) but share one `oid`.
- `--role-group` puts a group that holds the Cosmos data-plane role assignment into every token (**UNVERIFIED** how
  authorization maps these test principals; see step 2).
- Check the table: actual token length and `Authorization` header length per file. Keep the header length in mind
  when you compare against the limits (default 16384 gateway / 16000 RNTBD; 65536 gateway / ~65000 RNTBD raised).

### 2. Configure the test federation to trust the tokens

All of this is in the CosmosDB repo; names below were read from the code, anything not verifiable is marked
**UNVERIFIED**.

| What | Where | Value |
| --- | --- | --- |
| Signing public key | Federation naming config `aadPublicKeys` (`FederationConfiguration.ConfigurationProperties.AadPublicKeys`; consumed by `GatewayDatabaseAccountConfiguration` -> `AadAuthenticator`). Tests set it with `AadTestUtility.PopulateAadPublicKeysInFederationConfiguration` / `ManagementFrontendOperationsHelper.SetNamingConfigurationForFederation`. | The content of `jwks.json` (`{"keys":[{kty,use,kid,n,e}]}`). |
| Trusted tenant | Per database account: `DatabaseAccountBackendResource.TrustedAadTenants` (`trustedAadTenants`), a JSON array of GUIDs. | `["<tenantGuid>"]` |
| Audience | Generated from the account name and DNS zones (`GatewayDatabaseAccountConfiguration.GenerateListOfValidAadAudiences`): `https://<globalAccountName>.<waDnsZone>`, `https://<globalAccountName>.<sqlDnsZone>`, ... | Use the first form as `--audience`. |
| Use the key based `AadAuthenticator`, not MISE | `GatewayDatabaseAccountConfiguration` only reloads `aadPublicKeys` when `EnableMiseForManaged` is false. | `EnableMiseForManaged=false` on the federation (**UNVERIFIED** for your federation; with MISE the test key is not trusted). |
| Data-plane authorization | A role assignment for the `oid` or for `--role-group` on the account. | **UNVERIFIED**: how role assignments resolve fake principals. If authorization fails with 403 and not 401, fix this first. |
| AAD requests accepted by the backend | `AADTokenBackendAuthenticatorWrapper` is only consulted when its per-tenant `aadTokenRequestSupported` check passes. | **UNVERIFIED** which config drives this on your federation. |

Check authentication works at a small size (for example 4K, header well below every limit) before stepping up.

### 3. Configure the size limits (test federation)

- `rntbdIncomingRequestMaxMetadataSize` = ~65000 (backend, PR 2386646). **UNVERIFIED**: this name and its scope come
  from the task description; it is not in the CosmosDB tree that was inspected.
- `use64KBTokenBufferSizeLimit` = `true` (`FederationConfiguration.ConfigurationProperties.Use64KBTokenBufferSizeLimit`,
  read in `Authorizer.AuthorizeRequestAsync` through the account configuration reader; 16 KB vs 64 KB limit on the
  `Authorization` header string). **UNVERIFIED** whether it must be set federation or account wide.
- Keep a default (16000) run as the control: tokens above the limit must be rejected, tokens below must pass.
- The **gateway** has its own limits on the same header; see
  [Where metadata requests are served](#where-metadata-requests-are-served) for what must be raised there.

### 4. Upload the tokens

```powershell
az storage blob upload --account-name <acct> -c tokens -f tokens-16384.txt -n tokens-16384.txt --auth-mode login
$exp = (Get-Date).ToUniversalTime().AddHours(6).ToString("yyyy-MM-ddTHH:mmZ")
az storage blob generate-sas --account-name <acct> -c tokens -n tokens-16384.txt --permissions r --expiry $exp --https-only --full-uri --auth-mode login --as-user -o tsv
```

The SAS URL and the token files are credentials: do not log or commit them. Pass the URL only as the secure parameter
`aadTokenFileUrl`. (The tokens are only valid on the test federation, but still treat them as secrets.)

### 5. Deploy and run

The VMs fetch `execute.sh`/`custom-script.sh` from `benchmarkingToolsRepoName`/`benchmarkingToolsBranchName` and build
YCSB from `ycsbGitHubRepoName`/`ycsbGitHubBranchName`: point them to a branch of this repo that contains the AAD
plumbing, and to a YCSB fork/branch with `aad-credential-support.patch` applied.

1. Load once with the account key (no AAD parameters, `skipLoadPhase=false`).
2. For every token size run, with the same parameters except the tokens file:

| Parameter | Value |
| --- | --- |
| `aadTokenFileUrl` | SAS URL of `tokens-<size>.txt` |
| `aadTokenMode` | `single` (see step 6) |
| `cosmosKey` | required by the template; ignored by the binding when `aadTokenFile` is set (pass any placeholder) |
| `useGateway` | `false` (direct mode) |
| `workloadType` | `workloadc` (read only: the header cost is paid on every request, the body is small) |
| `requestdistribution` | `uniform` |
| `targetOperationsPerSecond` | fixed, identical for every size (below the saturation of the account/VM size, e.g. the rate at the 2K baseline) |
| `skipLoadPhase` | `true` |
| `ycsbOperationCount` / `threads` / `vmCount` | identical for every size; use a count that gives at least 10 minutes at the target rate |

3. Baseline: a managed identity run (`managedIdentityName` + `managedIdentityClientId`, real Entra token of ~2K, no
   `aadTokenFileUrl`) and/or a key-based run, to separate "AAD" from "token size" effects. The 2K minted token measures
   the cost of the test path itself.
4. Step the size: 2K (baseline), 4K, 8K, 16K, 24K, 32K, 48K, 60K. Repeat each size at least 3 times and also run the
   default limit configuration once to confirm the rejection behaviour above 16000.

### 6. Cache hit versus cache miss

- `single` mode: every request carries the same token, so any backend token validation cache is hit after the first
  request. This isolates the **transport/header cost** (RNTBD framing, buffers, copies) of a large token.
- `unique` mode (`aadTokenMode=unique`): presents the next token of the file when the SDK asks the credential for a
  token. The SDK caches tokens (`SimpleTokenCache`: refresh only near expiry, at most every 30 seconds), and YCSB shares
  one client across all threads, so **per-request uniqueness is NOT guaranteed**: roughly one new token per client every
  30 seconds. It exercises the validation path only marginally. See `cosmos/tools/ycsb-patches/README.md` for
  alternatives (several deployments with different token files).
- Whether the backend caches validated tokens, and by which key, is **UNVERIFIED** (`AadAuthenticator` itself has no
  cache; MISE has a validation result cache option). To measure the cache-miss cost (signature validation and claims
  parsing of a large token), microbenchmark `AadAuthenticator.Authenticate` (see `Security.AadAuthentication.Benchmark`)
  with the same tokens.

### 7. What to compare

For each size: throughput achieved vs target, p50/p99/p99.9 latency (YCSB output in the results storage account),
error counts/status codes (401/403/other), and on the backend CPU, memory, allocation rate/GC, and RNTBD connection
resets. Look for the knee where latency rises or throughput falls.

## Caveats

- Thin client mode caps the header at 16K; do not enable it for sizes above that.
- Gateway mode (`useGateway=true`) measures the gateway path (HTTP header limits, `Authorizer`), not the RNTBD limit.
- `fieldcount` changes the document body, not the headers; it does not change the token cost. Keep it constant.
- In direct mode the SDK also sends the token to the gateway for metadata requests; at a fixed rate this is small but
  shows up in the first minutes of a run (warm-up). Discard the first minutes.
- The token expiry is 72 h by default; mint a fresh set for long campaigns. `single` mode reports the JWT `exp` to the
  SDK.
- `JwtSecurityTokenHandler` has its own maximum token size (default 256 KB); not a limit at 60K, but **UNVERIFIED**
  whether the backend overrides it.

## Results template

| Token size (chars) | Header (chars) | Mode | Target ops/s | Achieved ops/s | p50 (ms) | p99 (ms) | p99.9 (ms) | Errors (status: count) | Backend CPU % | Backend mem / alloc | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| MI baseline (~2K) | | n/a | | | | | | | | | |
| 2048 | 2079 | single | | | | | | | | | |
| 4096 | 4127 | single | | | | | | | | | |
| 8192 | 8223 | single | | | | | | | | | |
| 16384 | 16415 | single | | | | | | | | | limit check |
| 24576 | 24607 | single | | | | | | | | | |
| 32768 | 32799 | single | | | | | | | | | |
| 49152 | 49183 | single | | | | | | | | | |
| 61440 | 61471 | single | | | | | | | | | |

### Metadata-heavy load (fill per `useGateway` value; fixed low rate, see the stop criteria)

| Token size (chars) | Header (chars) | `metadataOperation` / % | `useGateway` | Target ops/s | Achieved ops/s | p50 (ms) | p99 (ms) | Errors (status: count) | Gateway CPU % | Backend (master replica) CPU % | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 2048 (baseline) | 2079 | listContainers / 100 | false | | | | | | | | |
| 2048 (baseline) | 2079 | listContainers / 100 | true | | | | | | | | |
| 8192 | 8223 | listContainers / 100 | false | | | | | | | | |
| 8192 | 8223 | listContainers / 100 | true | | | | | | | | |
| 16384 | 16415 | listContainers / 100 | false | | | | | | | | limit check |
| 16384 | 16415 | listContainers / 100 | true | | | | | | | | limit check |
| 32768 | 32799 | listContainers / 100 | false | | | | | | | | |
| 32768 | 32799 | listContainers / 100 | true | | | | | | | | |
| 61440 | 61471 | listContainers / 100 | false | | | | | | | | |
| 61440 | 61471 | listContainers / 100 | true | | | | | | | | |
| 32768 | 32799 | mixed / 50 | false | | | | | | | | data/metadata mix |
