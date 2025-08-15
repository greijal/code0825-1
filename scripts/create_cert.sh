#!/usr/bin/env bash
# ============================================================
# create_cert.sh
# Gera CA interna + certificados para Keycloak e API Gateway
# usados para comunicação mTLS entre Nginx e upstreams.
#
# Estrutura de saída:
#   internal-ca/internal-ca.{crt,key}
#   internal-ca/keycloak/{keycloak.crt,keycloak.key,keycloak-chain.crt}
#   internal-ca/api-gateway/{api-gw.crt,api-gw.key,api-gw-chain.crt}
#
# Uso:
#   ./scripts/create_cert.sh
#   ./scripts/create_cert.sh --force   # força regeneração
#   ./scripts/create_cert.sh --verbose # mostra comandos
# ============================================================
set -euo pipefail
umask 077

# Defaults
DAYS_CA=3650
DAYS_SRV=825
KEYSIZE=4096
CN_CA="internal-ca.api.greijal.app"
KC_SANS_DEFAULT="keycloak,keycloak.internal"
GW_SANS_DEFAULT="api_gateway,api-gateway,api-gateway.internal"
FORCE=0
VERBOSE=0

# Args
KC_SANS="$KC_SANS_DEFAULT"
GW_SANS="$GW_SANS_DEFAULT"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --force) FORCE=1; shift ;;
    --verbose) VERBOSE=1; shift ;;
    --days-ca) DAYS_CA="$2"; shift 2 ;;
    --days-cert) DAYS_SRV="$2"; shift 2 ;;
    --keysize) KEYSIZE="$2"; shift 2 ;;
    --cn-ca) CN_CA="$2"; shift 2 ;;
    --kc-sans) KC_SANS="$2"; shift 2 ;;
    --gw-sans) GW_SANS="$2"; shift 2 ;;
    -h|--help)
      cat <<EOF
Uso: $0 [opções]
  --force                 Força regeneração (sobrescreve chaves/certs)
  --verbose               Mostra comandos openssl
  --days-ca N             Validade da CA (default: $DAYS_CA)
  --days-cert N           Validade dos certs (default: $DAYS_SRV)
  --keysize N             Tamanho das chaves (default: $KEYSIZE)
  --cn-ca CN              Common Name da CA (default: $CN_CA)
  --kc-sans "a,b,..."     SANs do Keycloak (default: $KC_SANS_DEFAULT)
  --gw-sans "a,b,..."     SANs do API Gateway (default: $GW_SANS_DEFAULT)
EOF
      exit 0
      ;;
    *) echo "Opção desconhecida: $1" >&2; exit 1 ;;
  esac
done
[[ $VERBOSE -eq 1 ]] && set -x

command -v openssl >/dev/null 2>&1 || { echo "Erro: openssl não encontrado no PATH"; exit 127; }

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [[ "$(basename "$ROOT_DIR")" == "scripts" ]]; then
  ROOT_DIR="$(cd "$ROOT_DIR/.." && pwd)"
fi

OUT_DIR="$ROOT_DIR/internal-ca"
KC_DIR="$OUT_DIR/keycloak"
GW_DIR="$OUT_DIR/api-gateway"
mkdir -p "$OUT_DIR" "$KC_DIR" "$GW_DIR"

CA_KEY="$OUT_DIR/internal-ca.key"
CA_CRT="$OUT_DIR/internal-ca.crt"
CA_SERIAL="$OUT_DIR/ca.srl"

mk_san_block() {
  local sans_csv="$1"
  local idx=1
  echo "[alt_names]"
  IFS=',' read -ra arr <<< "$sans_csv"
  for d in "${arr[@]}"; do
    d_trim="$(echo "$d" | xargs)"
    [[ -z "$d_trim" ]] && continue
    echo "DNS.$idx=$d_trim"
    idx=$((idx+1))
  done
}

# ---------- CA interna ----------
echo "==> CA interna (CN: $CN_CA)"
if [[ $FORCE -eq 1 || ! -f "$CA_KEY" || ! -f "$CA_CRT" ]]; then
  openssl genrsa -out "$CA_KEY" "$KEYSIZE"
  openssl req -x509 -new -nodes -key "$CA_KEY" -sha256 -days "$DAYS_CA" \
    -subj "/CN=$CN_CA" -out "$CA_CRT"
  [[ -f "$CA_SERIAL" ]] || echo "01" > "$CA_SERIAL"
  echo "CA criada: $CA_CRT"
else
  echo "CA já existe: $CA_CRT (use --force para regenerar)"
  [[ -f "$CA_SERIAL" ]] || echo "01" > "$CA_SERIAL"
fi

# ---------- Certificado Keycloak ----------
KC_KEY="$KC_DIR/keycloak.key"
KC_CRT="$KC_DIR/keycloak.crt"
KC_CHAIN="$KC_DIR/keycloak-chain.crt"
KC_CONF="$KC_DIR/openssl.cnf"

echo "==> Certificado Keycloak (SANs: $KC_SANS)"
if [[ $FORCE -eq 1 || ! -f "$KC_KEY" || ! -f "$KC_CRT" ]]; then
  cat > "$KC_CONF" <<EOF
[req]
distinguished_name=req_distinguished_name
x509_extensions=v3_req
prompt=no
[req_distinguished_name]
CN=keycloak.internal
[v3_req]
keyUsage=critical,digitalSignature,keyEncipherment
extendedKeyUsage=serverAuth
subjectAltName=@alt_names
$(mk_san_block "$KC_SANS")
EOF
  openssl genrsa -out "$KC_KEY" "$KEYSIZE"
  openssl req -new -key "$KC_KEY" -out "$KC_DIR/keycloak.csr" -config "$KC_CONF"
  openssl x509 -req -in "$KC_DIR/keycloak.csr" -CA "$CA_CRT" -CAkey "$CA_KEY" \
    -CAserial "$CA_SERIAL" -CAcreateserial \
    -out "$KC_CRT" -days "$DAYS_SRV" -sha256 -extfile "$KC_CONF" -extensions v3_req
  cat "$KC_CRT" "$CA_CRT" > "$KC_CHAIN"
  rm -f "$KC_DIR/keycloak.csr"
  chmod 600 "$KC_KEY"
  echo "Keycloak => crt: $KC_CRT | key: $KC_KEY"
else
  echo "Keycloak já existe: $KC_CRT"
fi

# ---------- Certificado API Gateway ----------
GW_KEY="$GW_DIR/api-gw.key"
GW_CRT="$GW_DIR/api-gw.crt"
GW_CHAIN="$GW_DIR/api-gw-chain.crt"
GW_CONF="$GW_DIR/openssl.cnf"

echo "==> Certificado API Gateway (SANs: $GW_SANS)"
if [[ $FORCE -eq 1 || ! -f "$GW_KEY" || ! -f "$GW_CRT" ]]; then
  cat > "$GW_CONF" <<EOF
[req]
distinguished_name=req_distinguished_name
x509_extensions=v3_req
prompt=no
[req_distinguished_name]
CN=api-gateway.internal
[v3_req]
keyUsage=critical,digitalSignature,keyEncipherment
extendedKeyUsage=serverAuth
subjectAltName=@alt_names
$(mk_san_block "$GW_SANS")
EOF
  openssl genrsa -out "$GW_KEY" "$KEYSIZE"
  openssl req -new -key "$GW_KEY" -out "$GW_DIR/api-gw.csr" -config "$GW_CONF"
  openssl x509 -req -in "$GW_DIR/api-gw.csr" -CA "$CA_CRT" -CAkey "$CA_KEY" \
    -CAserial "$CA_SERIAL" -CAcreateserial \
    -out "$GW_CRT" -days "$DAYS_SRV" -sha256 -extfile "$GW_CONF" -extensions v3_req
  cat "$GW_CRT" "$CA_CRT" > "$GW_CHAIN"
  rm -f "$GW_DIR/api-gw.csr"
  chmod 600 "$GW_KEY"
  echo "API Gateway => crt: $GW_CRT | key: $GW_KEY"
else
  echo "API Gateway já existe: $GW_CRT"
fi

echo
echo "Resumo:"
echo "CA interna:              $CA_CRT"
echo "Keycloak:                $KC_CRT  |  $KC_KEY  | chain: $KC_CHAIN"
echo "API Gateway:             $GW_CRT  |  $GW_KEY  | chain: $GW_CHAIN"
echo
echo "Próximos passos:"
echo "- Suba o stack: make up"
echo "- O Nginx externo precisa de cert público (use: make certs-public ou make certs-all)"