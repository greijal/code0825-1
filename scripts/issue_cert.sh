#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$DIR/certs/out"
mkdir -p "$OUT"
openssl req -x509 -newkey rsa:2048 -sha256 -days 365 -nodes       -subj "/CN=localhost"       -keyout "$OUT/server.key" -out "$OUT/server.crt"       -addext "subjectAltName=DNS:localhost,IP:127.0.0.1"
echo "Self-signed cert written to $OUT/server.crt and $OUT/server.key"
