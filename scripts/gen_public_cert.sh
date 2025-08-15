#!/usr/bin/env bash
# Gera/obtém certificado PÚBLICO para o Nginx externo (api.greijal.app):
# - copy: copia de Let's Encrypt do host (resolvendo symlinks), valida e sai com erro se não encontrar
# - copy-strict: igual ao copy, mas ABORTA se inválido (sem fallback)
# - self: gera autoassinado com SAN (uso temporário/dev)
# - auto: tenta copy; se falhar, cai para self com AVISO
#
# Saída: <out-dir>/fullchain.pem e <out-dir>/privkey.pem
#
# Uso:
#   bash scripts/gen_public_cert.sh --domain api.greijal.app --mode copy-strict --out-dir ./certs/le
set -euo pipefail
umask 077

MODE="copy-strict"
DOMAIN="api.greijal.app"
OUT_DIR="./certs/le"
DAYS=30
KEY_SIZE=4096

while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode) MODE="$2"; shift 2 ;;
    --domain) DOMAIN="$2"; shift 2 ;;
    --out-dir) OUT_DIR="$2"; shift 2 ;;
    --days) DAYS="$2"; shift 2 ;;
    --key-size) KEY_SIZE="$2"; shift 2 ;;
    -h|--help)
      cat <<EOF
Uso: $0 --domain <dominio> [--mode auto|copy|copy-strict|self] [--out-dir ./certs/le] [--days 30] [--key-size 2048]
Modos:
  copy         Copia de Let's Encrypt do host; falha se não encontrar/validar.
  copy-strict  Igual ao copy, sem fallback (recomendado para produção/CI).
  self         Gera autoassinado TEMPORÁRIO (dev).
  auto         Tenta copy; se falhar, gera autoassinado (com AVISO).
EOF
      exit 0
      ;;
    *)
      echo "Parâmetro desconhecido: $1" >&2
      exit 2
      ;;
  esac
done

mkdir -p "${OUT_DIR}"

guess_le_live_dir() {
  local d1="/private/etc/letsencrypt/live/${DOMAIN}" # macOS (caminho real)
  local d2="/etc/letsencrypt/live/${DOMAIN}"         # Linux
  if [[ -d "$d1" ]]; then
    echo "$d1"
  elif [[ -d "$d2" ]]; then
    echo "$d2"
  else
    echo ""
  fi
}

validate_pem_contains_domain() {
  local cert="$1"
  openssl x509 -in "$cert" -noout -text >/dev/null 2>&1 || return 1
  local san
  san="$(openssl x509 -in "$cert" -noout -text | grep -i 'Subject Alternative Name' -A1 | tail -n1 || true)"
  if ! echo "$san" | grep -q "DNS:${DOMAIN}"; then
    echo "SAN não contém DNS:${DOMAIN} em ${cert}" >&2
    return 1
  fi
  return 0
}

validate_public_issuer() {
  local cert="$1"
  local issuer
  issuer="$(openssl x509 -in "$cert" -noout -issuer 2>/dev/null || true)"
  if echo "$issuer" | grep -Eqi 'Let.?s Encrypt|ISRG'; then
    return 0
  fi
  echo "Issuer não aparenta ser Let's Encrypt/ISRG: ${issuer}" >&2
  return 1
}

copy_from_le() {
  local src_live
  src_live="$(guess_le_live_dir)"
  [[ -n "$src_live" ]] || { echo "Let's Encrypt live/ não encontrado para ${DOMAIN}"; return 1; }

  local full="${src_live}/fullchain.pem"
  local key="${src_live}/privkey.pem"
  [[ -f "$full" && -f "$key" ]] || { echo "Arquivos ausentes em ${src_live}"; return 1; }

  # Resolve symlinks
  cp -Lf "$full" "${OUT_DIR}/fullchain.pem"
  cp -Lf "$key"  "${OUT_DIR}/privkey.pem"
  chmod 644 "${OUT_DIR}/fullchain.pem"
  chmod 600 "${OUT_DIR}/privkey.pem"

  validate_pem_contains_domain "${OUT_DIR}/fullchain.pem"
  validate_public_issuer "${OUT_DIR}/fullchain.pem" || true

  echo "OK: certificados públicos copiados para ${OUT_DIR}"
}

make_self_signed() {
  local full="${OUT_DIR}/fullchain.pem"
  local key="${OUT_DIR}/privkey.pem"
  local cfg; cfg="$(mktemp)"
  cat > "$cfg" <<EOF
[req]
default_bits       = ${KEY_SIZE}
prompt             = no
default_md         = sha256
x509_extensions    = v3_req
distinguished_name = dn
[dn]
C = BR
ST = SP
L = Sao Paulo
O = DevLab
CN = ${DOMAIN}
[v3_req]
subjectAltName     = @alt_names
keyUsage           = keyEncipherment, dataEncipherment, digitalSignature
extendedKeyUsage   = serverAuth
[alt_names]
DNS.1 = ${DOMAIN}
EOF
  openssl req -x509 -newkey "rsa:${KEY_SIZE}" -nodes -days "${DAYS}" \
    -config "$cfg" -extensions v3_req \
    -keyout "$key" -out "$full"
  chmod 644 "$full"; chmod 600 "$key"; rm -f "$cfg"
  echo "ATENÇÃO: Gerado autoassinado TEMPORÁRIO em ${OUT_DIR}. NÃO usar em produção."
}

case "$MODE" in
  copy)        copy_from_le ;;
  copy-strict) copy_from_le ;; # sem fallback
  self)        make_self_signed ;;
  auto)        copy_from_le || { echo "Fallback para autoassinado (DEV)"; make_self_signed; } ;;
  *) echo "Modo inválido: $MODE"; exit 2 ;;
esac

echo
echo "Resumo:"
echo "  fullchain.pem -> ${OUT_DIR}/fullchain.pem"
echo "  privkey.pem   -> ${OUT_DIR}/privkey.pem"