#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$DIR/certs/out"
mkdir -p "$OUT"
openssl req -x509 -newkey rsa:2048 -sha256 -days 365 -nodes       -subj "/CN=api.greijal.app"       -keyout "$OUT/server.key" -out "$OUT/server.crt"       -addext "subjectAltName=DNS:api.greijal.app,IP:127.0.0.1"
chmod 600 certs/out/server.key || true
echo "Self-signed cert written to $OUT/server.crt and $OUT/server.key"
