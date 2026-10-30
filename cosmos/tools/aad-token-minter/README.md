# AAD token minter

`mint_aad_tokens.py` creates **test-only** AAD (Entra) style JWTs of a controlled size, signed with a local RSA key.
They are only accepted by a test federation that trusts the public key in `jwks.json`. See
[../../docs/aad-token-size-testing.md](../../docs/aad-token-size-testing.md) for the end-to-end runbook.

```powershell
pip install -r requirements.txt          # Python 3.9+
python mint_aad_tokens.py --audience https://<account>.documents.azure.com `
    --tenant-id <trusted-tenant-guid> --role-group <group-guid-with-cosmos-role> `
    --target-size-bytes 4096 8192 16384 32768 61440 --count 50 --out tokens.txt
```

Outputs `tokens-<size>.txt` (one token per line), `jwks.json` (public key, for the federation `aadPublicKeys` naming
config) and `signing-key.pem` (private key, reused on the next run). Generated files are git-ignored; never commit them.
A table with the actual token length and the URL encoded `Authorization` header length is printed.

Useful options: `--groups N` (explicit group count instead of a size), `--size-basis header` (target the header
length), `--service-principal` (`idtyp=app` instead of `scp`), `--distinct-oid`, `--expiry-hours`, `--seed`.
