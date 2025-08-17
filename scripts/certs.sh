#!/usr/bin/env bash
set -euo pipefail
KEYSTORE_FILE=${1:-}
KEYSTORE_PASSWORD=${2:-}
KEY_ALIAS=${3:-}
CERT_PUBLIC_FILE=${4:-}


if [[ -z "$KEYSTORE_FILE" || -z "$KEYSTORE_PASSWORD" || -z "$KEY_ALIAS" ]]; then
  echo "[certs] Uso: $(basename "$0") <KEYSTORE_FILE> <KEYSTORE_PASSWORD> <KEY_ALIAS> <CERT_PUBLIC_FILE>" >&2
  exit 1
fi

mkdir -p "$(dirname "$KEYSTORE_FILE")"

if command -v keytool >/dev/null 2>&1; then
  echo "[certs] Usando keytool local"
  keytool -genkeypair \
    -storepass "$KEYSTORE_PASSWORD" \
    -keypass "$KEYSTORE_PASSWORD" \
    -storetype PKCS12 \
    -keyalg RSA \
    -keysize 4096 \
    -dname "CN=server" \
    -alias "$KEY_ALIAS" \
    -ext "SAN:c=DNS:localhost,IP:127.0.0.1" \
    -keystore "$KEYSTORE_FILE"
    keytool -exportcert \
    -rfc \
    -alias "$KEY_ALIAS" \
    -keystore "$KEYSTORE_FILE" \
    -storepass "$KEYSTORE_PASSWORD" \
    -file "$CERT_PUBLIC_FILE"

else
  echo "[certs] keytool não encontrado, usando container JDK"
  docker run --rm -v "$(pwd)":/work -w /work eclipse-temurin:21-jdk \
    keytool -genkeypair \
      -storepass "$KEYSTORE_PASSWORD" \
      -keypass "$KEYSTORE_PASSWORD" \
      -storetype PKCS12 \
      -keyalg RSA \
      -keysize 4096 \
      -dname "CN=server" \
      -alias "$KEY_ALIAS" \
      -ext "SAN:c=DNS:localhost,IP:127.0.0.1" \
      -keystore "$KEYSTORE_FILE"
      keytool -exportcert \
      -rfc \
      -alias "$KEY_ALIAS" \
      -keystore "$KEYSTORE_FILE" \
      -storepass "$KEYSTORE_PASSWORD" \
      -file "$CERT_PUBLIC_FILE"

fi

echo "[certs] Keystore gerado em $KEYSTORE_FILE"
