#!/usr/bin/env python3
# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.
"""Mint test-only AAD (Entra) style tokens of a controlled size for Cosmos DB backend load tests.

The tokens are signed with a locally generated RSA key and are accepted only by a test federation that trusts the
public key written to --jwks-out (federation naming config "aadPublicKeys"), the tenant (account config
"trustedAadTenants") and the audience. They mimic the claims produced by AadTestUtility.CreateAadToken in the CosmosDB
repo:

    tid, oid, scp (or idtyp=app), groups (JSON array of GUIDs), aud, iss=https://sts.fake-windows.net/{issuer}/,
    iat/nbf/exp, uti

The token size is controlled by the number of GUIDs in the "groups" claim (about 52 token characters per group).
"""

import argparse
import base64
import hashlib
import json
import os
import random
import sys
import time
import uuid

try:
    import jwt  # PyJWT
    from cryptography.hazmat.primitives import serialization
    from cryptography.hazmat.primitives.asymmetric import rsa
except ImportError:
    sys.exit("Missing dependencies. Run: pip install -r requirements.txt")

AUTH_PREFIX = "type=aad&ver=1.0&sig="
# Characters java.net.URLEncoder leaves untouched (besides ASCII letters and digits).
URL_ENCODER_SAFE = ".-*_"
# Base64url characters of one "groups" entry: 36 char GUID + 2 quotes + 1 comma = 39 JSON bytes -> 52 characters.
CHARS_PER_GROUP = 52


def java_url_encode(value):
    """Same output as java.net.URLEncoder.encode(value, "UTF-8"), which the Cosmos Java SDK uses for AAD tokens."""
    out = []
    for byte in value.encode("utf-8"):
        char = chr(byte)
        if byte < 0x80 and (char.isalnum() or char in URL_ENCODER_SAFE):
            out.append(char)
        elif char == " ":
            out.append("+")
        else:
            out.append("%%%02X" % byte)
    return "".join(out)


def authorization_header_length(token):
    return len(java_url_encode(AUTH_PREFIX + token))


def load_or_create_key(key_file):
    if os.path.exists(key_file):
        with open(key_file, "rb") as handle:
            return serialization.load_pem_private_key(handle.read(), password=None), False
    private_key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
    pem = private_key.private_bytes(
        serialization.Encoding.PEM, serialization.PrivateFormat.PKCS8, serialization.NoEncryption())
    with open(key_file, "wb") as handle:
        handle.write(pem)
    return private_key, True


def b64url_uint(value):
    raw = value.to_bytes((value.bit_length() + 7) // 8, "big")
    return base64.urlsafe_b64encode(raw).rstrip(b"=").decode("ascii")


def default_kid(private_key):
    modulus = private_key.public_key().public_numbers().n
    digest = hashlib.sha256(modulus.to_bytes((modulus.bit_length() + 7) // 8, "big")).digest()
    return str(uuid.UUID(bytes=digest[:16]))


def build_jwks(private_key, kid):
    numbers = private_key.public_key().public_numbers()
    return {
        "keys": [
            {"kty": "RSA", "use": "sig", "kid": kid, "n": b64url_uint(numbers.n), "e": b64url_uint(numbers.e)}
        ]
    }


def random_guid(rng):
    return str(uuid.UUID(int=rng.getrandbits(128), version=4))


class Minter:
    def __init__(self, args, private_key, kid):
        self.args = args
        self.private_key = private_key
        self.kid = kid
        self.rng = random.Random(args.seed)
        now = int(time.time())
        self.iat = now
        self.nbf = now - 300
        self.exp = now + int(args.expiry_hours * 3600)

    def mint(self, group_count, oid, pad_chars=0):
        args = self.args
        groups = [random_guid(self.rng) for _ in range(group_count)]
        if args.role_group:
            # Keep the role assigned group present, at a random position so it is not always first or last.
            groups.insert(self.rng.randint(0, len(groups)), args.role_group)
        claims = {
            "aud": args.audience,
            "iss": "https://sts.fake-windows.net/%s/" % args.issuer_id,
            "iat": self.iat,
            "nbf": self.nbf,
            "exp": self.exp,
            "tid": args.tenant_id,
            "oid": oid,
            "uti": base64.urlsafe_b64encode(self.rng.randbytes(16)).rstrip(b"=").decode("ascii"),
        }
        if args.service_principal:
            claims["idtyp"] = "app"
            claims["appid"] = oid
        else:
            claims["scp"] = args.scope
        if groups:
            claims["groups"] = groups
        if pad_chars > 0:
            claims["pad"] = "x" * pad_chars
        return jwt.encode(claims, self.private_key, algorithm="RS256", headers={"kid": self.kid})


def plan_size(minter, target_token_len, oid, exact):
    """Return (group_count, pad_chars) for tokens that are as close as possible to target_token_len."""
    base_len = len(minter.mint(0, oid))
    group_count = max(0, (target_token_len - base_len) // CHARS_PER_GROUP)
    length = len(minter.mint(group_count, oid))
    while length > target_token_len and group_count > 0:
        group_count -= 1
        length = len(minter.mint(group_count, oid))
    if not exact or length == target_token_len:
        return group_count, 0
    # Close the remaining gap (less than one group) with a filler claim. The first filler char also adds the claim
    # name overhead and base64 rounds in steps of 3 bytes, so search for the best fit.
    best = (abs(target_token_len - length), 0)
    for pad in range(1, 81):
        best = min(best, (abs(target_token_len - len(minter.mint(group_count, oid, pad))), pad))
        if best[0] == 0:
            break
    return group_count, best[1]


def verify(tokens, jwks, args):
    public_key = jwt.PyJWK(jwks["keys"][0]).key
    for token in tokens[:3] + tokens[-1:]:
        jwt.decode(
            token,
            public_key,
            algorithms=["RS256"],
            audience=args.audience,
            issuer="https://sts.fake-windows.net/%s/" % args.issuer_id,
        )


def parse_args(argv):
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    size = parser.add_mutually_exclusive_group(required=True)
    size.add_argument("--groups", type=int, nargs="+", metavar="N", help="Number of GUIDs in the groups claim.")
    size.add_argument(
        "--target-size-bytes", type=int, nargs="+", metavar="B",
        help="Target size; the number of groups (and a small filler claim) is computed to hit it.")
    parser.add_argument(
        "--size-basis", choices=["token", "header"], default="token",
        help="What --target-size-bytes measures: the raw token or the URL encoded Authorization header value.")
    parser.add_argument("--no-exact", action="store_true", help="Do not add a filler claim to hit the size exactly.")
    parser.add_argument("--count", type=int, default=1, help="Number of distinct tokens per size (default 1).")
    parser.add_argument("--tenant-id", default=str(uuid.uuid4()), help="tid claim; must be a trusted tenant.")
    parser.add_argument("--issuer-id", help="GUID in the issuer URL; must be a trusted tenant. Default: tenant id.")
    parser.add_argument("--oid", help="Object id for all tokens. Default: one random GUID shared by all tokens.")
    parser.add_argument(
        "--distinct-oid", action="store_true",
        help="Use a different oid per token. Every oid needs its own role assignment; by default tokens are made "
             "distinct by their groups and uti claim only.")
    parser.add_argument(
        "--role-group", help="GUID of a group that has the Cosmos role assignment; always included in groups.")
    parser.add_argument("--audience", required=True, help="e.g. https://<account>.documents.azure.com")
    parser.add_argument("--scope", default="user_impersonation", help="scp claim (default user_impersonation).")
    parser.add_argument(
        "--service-principal", action="store_true", help="Emit idtyp=app (and no scp claim) like a service principal.")
    parser.add_argument("--expiry-hours", type=float, default=72, help="Token lifetime in hours (default 72).")
    parser.add_argument("--key-file", default="signing-key.pem", help="PEM private key to reuse, or create.")
    parser.add_argument("--kid", help="Key id in the JWKS and token header. Default: derived from the public key.")
    parser.add_argument("--out", default="tokens.txt", help="Output file, one token per line (default tokens.txt).")
    parser.add_argument("--jwks-out", default="jwks.json", help="Public JWKS to configure on the test federation.")
    parser.add_argument("--seed", type=int, help="Seed for reproducible group GUIDs and token ids.")
    args = parser.parse_args(argv)
    args.issuer_id = args.issuer_id or args.tenant_id
    for name in ("tenant_id", "issuer_id", "oid", "role_group"):
        value = getattr(args, name)
        if value:
            try:
                uuid.UUID(value)
            except ValueError:
                parser.error("--%s must be a GUID" % name.replace("_", "-"))
    if args.count < 1:
        parser.error("--count must be at least 1")
    return args


def output_path(path, size_label, multiple):
    if not multiple:
        return path
    root, ext = os.path.splitext(path)
    return "%s-%s%s" % (root, size_label, ext)


def main(argv=None):
    args = parse_args(argv if argv is not None else sys.argv[1:])

    private_key, created = load_or_create_key(args.key_file)
    kid = args.kid or default_kid(private_key)
    jwks = build_jwks(private_key, kid)
    with open(args.jwks_out, "w", encoding="utf-8") as handle:
        json.dump(jwks, handle, indent=2)

    shared_oid = args.oid or str(uuid.uuid4())
    minter = Minter(args, private_key, kid)
    oid_rng = random.Random(args.seed)

    def oid_for(index):
        return random_guid(oid_rng) if args.distinct_oid and index > 0 else shared_oid

    requested = args.groups or args.target_size_bytes
    rows = []
    for value in requested:
        if args.groups:
            group_count, pad = value, 0
        else:
            prefix = len(java_url_encode(AUTH_PREFIX)) if args.size_basis == "header" else 0
            group_count, pad = plan_size(minter, value - prefix, shared_oid, not args.no_exact)
        tokens = [minter.mint(group_count, oid_for(i), pad) for i in range(args.count)]
        if len(set(tokens)) != len(tokens):
            sys.exit("Generated tokens are not distinct.")
        verify(tokens, jwks, args)

        path = output_path(args.out, str(value), len(requested) > 1)
        with open(path, "w", encoding="utf-8", newline="\n") as handle:
            handle.write("\n".join(tokens) + "\n")
        lengths = [len(token) for token in tokens]
        headers = [authorization_header_length(token) for token in tokens]
        rows.append((value, path, len(tokens), group_count, min(lengths), max(lengths), max(headers)))

    print("Signing key: %s (kid %s)%s" % (args.key_file, kid, " [new]" if created else " [reused]"))
    print("JWKS: %s  tenant: %s  issuer: %s  audience: %s" % (
        args.jwks_out, args.tenant_id, args.issuer_id, args.audience))
    print()
    header = "%-10s %-24s %6s %7s %10s %10s %12s" % (
        "requested", "file", "count", "groups", "token min", "token max", "auth header")
    print(header)
    print("-" * len(header))
    for value, path, count, groups, min_len, max_len, header_len in rows:
        print("%-10s %-24s %6d %7d %10d %10d %12d" % (value, path, count, groups, min_len, max_len, header_len))
    print()
    print("Lengths are in characters (all ASCII, so bytes). Do not commit the key, tokens or JWKS.")


if __name__ == "__main__":
    main()
