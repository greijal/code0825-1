#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p out
openssl genrsa -out out/ca.key 4096 >/dev/null 2>&1
openssl req -x509 -new -nodes -key out/ca.key -sha256 -days 3650 -subj "/CN=local-ca" -out out/ca.crt >/dev/null 2>&1
echo "CA generated at certs/out/ca.crt"