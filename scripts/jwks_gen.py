#!/usr/bin/env python3
import sys, base64, json
from Crypto.PublicKey import RSA

def b64url(b):
    return base64.urlsafe_b64encode(b).rstrip(b"=").decode()

if len(sys.argv) != 3:
    print("usage: jwks_gen.py <public.pem> <kid>", file=sys.stderr)
    sys.exit(1)
with open(sys.argv[1], "rb") as f:
    key = RSA.import_key(f.read())
n = b64url(key.n.to_bytes((key.n.bit_length()+7)//8, 'big'))
e = b64url(key.e.to_bytes((key.e.bit_length()+7)//8, 'big'))
jwk = {"kty":"RSA","e":e,"n":n,"alg":"RS256","kid":sys.argv[2],"use":"sig"}
jwks = {"keys":[jwk]}
print(json.dumps(jwks, separators=(",",":")))
