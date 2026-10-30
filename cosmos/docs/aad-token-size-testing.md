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
| `cosmos/infra/azuredeploy.json` | New optional parameters `aadTokenFileUrl`, `aadTokenMode`, `managedIdentityName`, `managedIdentityClientId`; passed to the VMs as `AAD_TOKEN_FILE_URL`, `AAD_TOKEN_MODE`, `MANAGED_IDENTITY_CLIENT_ID`. |
| `cosmos/scripts/custom-script.sh` | Downloads the tokens file to `/tmp/aad-tokens.txt` and passes `aadTokenFile`, `aadTokenMode`, `managedIdentityClientId` to `azurecosmos-run.sh`. |
| `cosmos/scripts/azurecosmos-run.sh` | Writes `azurecosmos.aadTokenFile`, `azurecosmos.aadTokenMode`, `azurecosmos.managedIdentityClientId` into `azurecosmos.properties`. |
| YCSB `azurecosmos` binding (**Azure/YCSB repo**) | Presents the tokens to Cosmos DB. Needs `cosmos/tools/ycsb-patches/aad-credential-support.patch` (not yet in Azure/YCSB). |
| Cosmos DB Java SDK -> gateway / backend | Sends `Authorization: type=aad&ver=1.0&sig=<token>` (URL encoded) on every request. |

Key facts (verified against the CosmosDB repo and the Java SDK 4.67.0 used by Azure/YCSB):

- The Java SDK builds the header with `URLEncoder.encode("type=aad&ver=1.0&sig=" + token, "UTF-8")`
  (`AadTokenAuthorizationHelper`). A JWT only contains `A-Za-z0-9-_.`, so the header is exactly **token length + 31**
  characters. The minter prints both.
- Direct mode: metadata/address requests go through the gateway, data requests go over RNTBD to the backend replica,
  which authenticates AAD tokens in `AADTokenBackendAuthenticatorWrapper` using the tenant's `AadAuthenticator`.
  Both carry the token, but only the backend path is subject to the RNTBD header limit, hence `useGateway=false`.
- The gateway (`Authorizer.AuthorizeRequestAsync`) rejects an `Authorization` header longer than 16384 characters, or
  65536 when `use64KBTokenBufferSizeLimit` is true.

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
