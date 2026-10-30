# YCSB `azurecosmos` AAD credential patch

`aad-credential-support.patch` is a reference patch for the **Azure/YCSB** repository (the `azurecosmos` binding is not
part of this repo; the VMs clone it from `ycsbGitHubRepoName`/`ycsbGitHubBranchName`). Do not push it to Azure/YCSB
without review; apply it to a fork or branch and point the deployment at it.

Status: compiled and checkstyle-clean with JDK 17 and Maven 3.9.6
(`mvn -pl site.ycsb:azurecosmos-binding -am -DskipTests package`); `git apply --check` passes on Azure/YCSB commit
`34539b4` (main). It has not been run against a Cosmos DB endpoint.

## What it changes

- `AzureCosmosClient`: `azurecosmos.primaryKey` is optional when an AAD option is set. Precedence:
  1. `azurecosmos.aadTokenFile` -> `FileTokenCredential`
  2. `azurecosmos.managedIdentityClientId` -> `ManagedIdentityCredentialBuilder().clientId(..)`
  3. `azurecosmos.primaryKey` (unchanged behaviour)
- New `FileTokenCredential` (`TokenCredential`): reads one token per line. `azurecosmos.aadTokenMode`:
  - `single` (default): always returns the first token; the expiry reported to the SDK is the JWT `exp` claim (fallback
    now + 1 hour).
  - `unique`: returns the next token (round robin, `AtomicLong` index) on each `getToken` call.
- `azurecosmos/pom.xml`: adds `com.azure:azure-identity:1.13.3` (it is not a dependency of `azure-cosmos`).
- `azurecosmos/conf/azurecosmos.properties`: commented defaults for the three new properties.

## Apply

```powershell
git clone https://github.com/<you>/YCSB; cd YCSB
git checkout -b aad-credential-support
git apply path\to\azure-db-benchmarking\cosmos\tools\ycsb-patches\aad-credential-support.patch
```

## `unique` mode does NOT mean one token per request

The Cosmos Java SDK (checked in `azure-cosmos` 4.67.0, the version used by Azure/YCSB: `RxDocumentClientImpl` creates a
`com.azure.core.credential.SimpleTokenCache` and `AadTokenAuthorizationHelper` takes the token from it for every
request) caches the token returned by the credential. `SimpleTokenCache` calls the credential again only when the cached
token is within 5 minutes of its expiry, and then at most once every 30 seconds (behaviour read from azure-core `main`;
the constants were not re-verified for azure-core 1.55.2). YCSB also shares one `CosmosClient` across all threads.

So with `unique` mode every request of the process presents the same token for up to ~30 seconds, then the next token
from the file. To make the credential refresh every 30 seconds instead of once per token lifetime, `unique` mode
reports a 5 minute expiry to the SDK (the real JWT `exp` is still validated by the backend).

Per-request uniqueness (to defeat a backend token validation cache) is not achievable through `TokenCredential` without
bypassing the SDK cache (for example reflection on SDK internals, which is fragile and not done here). Alternatives:

- Run many client instances (several deployments, each with its own `aadTokenFileUrl`, since all VMs of one
  deployment get the same file) so the backend sees many different tokens concurrently.
- Measure the cache-miss cost directly on the backend (microbenchmark `AadAuthenticator.Authenticate`) and use this
  load test for the transport/header path.
