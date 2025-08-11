#!/usr/bin/env python3
import sys, base64, json, re
from Crypto.PublicKey import RSA

# Implementação sem dependências externas além de PyCryptodome já incluída no ambiente de execução deste pacote.
# Entrada: jwks_gen.py <public.pem> <kid>
def b64url(b: bytes) -> str:
    return base64.urlsafe_b64encode(b).rstrip(b'=').decode('ascii')

def load_rsa_pub(path):
    with open(path, 'rb') as f:
        key = RSA.import_key(f.read())
    n = key.n.to_bytes((key.n.bit_length() + 7)//8, 'big')
    e = key.e.to_bytes((key.e.bit_length() + 7)//8, 'big')
    return n, e

def main():
    if len(sys.argv) < 3:
        print("usage: jwks_gen.py <public.pem> <kid>", file=sys.stderr)
        sys.exit(1)
    pub, kid = sys.argv[1], sys.argv[2]
    n, e = load_rsa_pub(pub)
    jwk = {
        "kty": "RSA",
        "use": "sig",
        "alg": "RS256",
        "kid": kid,
        "n": b64url(n),
        "e": b64url(e),
    }
    jwks = {"keys": [jwk]}
    print(json.dumps(jwks, separators=(',',':')))

if __name__ == "__main__":
    main()