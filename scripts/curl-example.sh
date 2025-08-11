#!/usr/bin/env bash
set -euo pipefail
MODE="${1:-local}"
BASE="https://localhost:8443"
if [[ "$MODE" == "prod" ]]; then
  BASE="https://api.greijal.app"
fi

CLIENT_ASSERTION_FILE="resource-server/client-keys/client_assertion.jwt"
if [[ ! -f "$CLIENT_ASSERTION_FILE" ]]; then
  echo "Gere o client_assertion: make client-assertion-$MODE"
  exit 1
fi
CLIENT_ASSERTION=$(cat "$CLIENT_ASSERTION_FILE")
CLIENT_ID="api-client"

# 1) token
TOKEN_JSON=$(curl -sk -X POST "$BASE/kc/realms/api/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  --data-urlencode "grant_type=client_credentials" \
  --data-urlencode "client_id=$CLIENT_ID" \
  --data-urlencode "client_assertion_type=urn:ietf:params:oauth:client-assertion-type:jwt-bearer" \
  --data-urlencode "client_assertion=$CLIENT_ASSERTION")
ACCESS_TOKEN=$(echo "$TOKEN_JSON" | python3 -c 'import sys,json; print(json.load(sys.stdin).get("access_token",""))')

if [[ -z "$ACCESS_TOKEN" ]]; then
  echo "Falha ao obter access_token. Resposta:"
  echo "$TOKEN_JSON"
  exit 2
fi

echo "Token OK, chamando API /api/hello"
curl -sk "$BASE/api/hello" -H "Authorization: Bearer $ACCESS_TOKEN" | python3 -c 'import sys,json; print(json.dumps(json.load(sys.stdin), indent=2))'