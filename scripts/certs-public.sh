#!/usr/bin/env bash
set -euo pipefail

# Usage: bash scripts/certs-public.sh <KEYSTORE_FILE> <KEYSTORE_PASSWORD> <KEY_ALIAS> <CERT_PUBLIC_FILE>

if [[ $# -ne 4 ]]; then
  echo "Usage: $0 <KEYSTORE_FILE> <KEYSTORE_PASSWORD> <KEY_ALIAS> <CERT_PUBLIC_FILE>" >&2
  exit 2
fi

KEYSTORE_FILE="$1"
KEYSTORE_PASSWORD="$2"
KEY_ALIAS="$3"
CERT_PUBLIC_FILE="$4"

# Check keystore exists
if [[ ! -f "$KEYSTORE_FILE" ]]; then
  echo "Keystore não encontrado em ${KEYSTORE_FILE}. Rode 'make certs' primeiro." >&2
  exit 3
fi

# Export certificate using local keytool or Docker fallback
if command -v keytool >/dev/null 2>&1; then
  keytool -exportcert -rfc -alias "$KEY_ALIAS" -keystore "$KEYSTORE_FILE" -storepass "$KEYSTORE_PASSWORD" -file "$CERT_PUBLIC_FILE"
else
  echo "[certs-public] keytool não encontrado, usando container JDK"
  docker run --rm -v "$PWD":/work -w /work eclipse-temurin:21-jdk \
    keytool -exportcert -rfc -alias "$KEY_ALIAS" -keystore "$KEYSTORE_FILE" -storepass "$KEYSTORE_PASSWORD" -file "$CERT_PUBLIC_FILE"
fi

echo "[certs-public] Certificado salvo em ${CERT_PUBLIC_FILE}"