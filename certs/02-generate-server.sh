#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p out
cat > out/openssl.cnf <<EOF
[ req ]
distinguished_name = dn
[ dn ]
[ v3_req ]
subjectAltName = @alt_names
[ alt_names ]
DNS.1 = localhost
IP.1 = 127.0.0.1
DNS.2 = api.greijal.app
EOF
openssl genrsa -out out/server.key 2048 >/dev/null 2>&1
openssl req -new -key out/server.key -subj "/CN=localhost" -out out/server.csr -config out/openssl.cnf >/dev/null 2>&1
openssl x509 -req -in out/server.csr -CA out/ca.crt -CAkey out/ca.key -CAcreateserial -out out/server.crt -days 365 -sha256 -extensions v3_req -extfile out/openssl.cnf >/dev/null 2>&1
echo "Server cert generated at certs/out/server.crt"