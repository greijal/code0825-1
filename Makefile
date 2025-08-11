SHELL := /bin/bash
COMPOSE_LOCAL := docker-compose.local.yml
COMPOSE_PROD  := docker-compose.prod.yml

GATEWAY_LOCAL := $(shell docker compose -f $(COMPOSE_LOCAL) ps -q gateway)
GATEWAY_PROD  := $(shell docker compose -f $(COMPOSE_PROD)  ps -q gateway)

CLIENT_KEYS_DIR := resource-server/client-keys
JWKS_FILE := $(CLIENT_KEYS_DIR)/jwks.json
PUB_PEM   := $(CLIENT_KEYS_DIR)/public.pem
PRV_PEM   := $(CLIENT_KEYS_DIR)/private.pem

STATIC_DIR := resource-server/static/.well-known
STATIC_JWKS := $(STATIC_DIR)/api-client.jwks.json

NODE_BIN := node
NPM_BIN  := npm

.PHONY: up-local up-prod down logs-local logs-prod \
        keys-gen jwks-gen jwks-publish-local jwks-publish-prod \
        client-assertion-local client-assertion-prod ensure-jose \
        reload-nginx-local reload-nginx-prod \
        health-local health-prod smoke-local smoke-prod \
        postman-export tls-gen lint

### ===== Base =====
up-local: tls-gen
	@echo "▶ Subindo LOCAL (https://localhost:8443)"
	docker compose --env-file .env.local -f $(COMPOSE_LOCAL) up -d --build
	$(MAKE) jwks-publish-local
	$(MAKE) health-local

up-prod: tls-gen
	@echo "▶ Subindo PROD (api.greijal.app)"
	docker compose --env-file .env.prod -f $(COMPOSE_PROD) up -d --build
	$(MAKE) jwks-publish-prod
	$(MAKE) health-prod

down:
	docker compose -f $(COMPOSE_LOCAL) down -v || true
	docker compose -f $(COMPOSE_PROD)  down -v || true

logs-local:
	docker compose -f $(COMPOSE_LOCAL) logs -f --tail=200

logs-prod:
	docker compose -f $(COMPOSE_PROD) logs -f --tail=200

### ===== TLS self-signed para Nginx (local/prod origin) =====
tls-gen:
	@echo "▶ Gerando TLS self-signed (se necessário)"
	mkdir -p certs/out
	if [[ ! -f "certs/out/server.crt" || ! -f "certs/out/server.key" ]]; then \
	  bash certs/01-generate-ca.sh >/dev/null && \
	  bash certs/02-generate-server.sh >/dev/null; \
	  echo "OK: certs/out/server.crt e server.key prontos"; \
	else echo "OK: certificados já existem"; fi

### ===== Chaves & JWKS (cliente S2S) =====
keys-gen:
	@echo "▶ Gerando chaves do cliente (se faltarem)"
	mkdir -p $(CLIENT_KEYS_DIR)
	if [[ ! -f "$(PRV_PEM)" || ! -f "$(PUB_PEM)" ]]; then \
	  openssl genrsa -out $(PRV_PEM) 2048 && \
	  openssl rsa -in $(PRV_PEM) -pubout -out $(PUB_PEM) && \
	  chmod 600 $(PRV_PEM); \
	  echo "OK: chaves criadas em $(CLIENT_KEYS_DIR)"; \
	else \
	  echo "OK: chaves já existem, mantendo."; \
	fi

jwks-gen: keys-gen
	@echo "▶ Gerando JWKS a partir do public.pem (sem deps externas)"
	python3 resource-server/scripts/jwks_gen.py $(PUB_PEM) api-client-demo > $(JWKS_FILE)

jwks-publish-local: jwks-gen
	@echo "▶ Publicando JWKS no Nginx LOCAL"
	mkdir -p $(STATIC_DIR)
	cp $(JWKS_FILE) $(STATIC_JWKS)
	$(MAKE) reload-nginx-local
	@echo "OK: https://localhost:8443/.well-known/api-client.jwks.json publicado"

jwks-publish-prod: jwks-gen
	@echo "▶ Publicando JWKS no Nginx PROD"
	mkdir -p $(STATIC_DIR)
	cp $(JWKS_FILE) $(STATIC_JWKS)
	$(MAKE) reload-nginx-prod
	@echo "OK: https://api.greijal.app/.well-known/api-client.jwks.json publicado"

### ===== Client Assertion (private_key_jwt) =====
ensure-jose:
	@echo "▶ Checando jose (Node)…"
	if ! command -v $(NODE_BIN) >/dev/null; then echo "ERRO: Node não encontrado. Instale Node.js."; exit 1; fi
	@if ! $(NODE_BIN) -e "require('jose')" >/dev/null 2>&1; then \
	  echo "Instalando jose local (sem global)…"; \
	  (cd resource-server/scripts && $(NPM_BIN) init -y >/dev/null 2>&1 || true && $(NPM_BIN) i jose >/dev/null); \
	else echo "OK: jose disponível"; fi

client-assertion-local: ensure-jose keys-gen
	@echo "▶ Gerando client_assertion (LOCAL)"
	$(NODE_BIN) resource-server/scripts/make_client_assertion.mjs \
	  --key $(PRV_PEM) \
	  --kid api-client-demo \
	  --client-id api-client \
	  --aud https://localhost:8443/kc/realms/api/protocol/openid-connect/token \
	  > $(CLIENT_KEYS_DIR)/client_assertion.jwt
	@echo "OK: $(CLIENT_KEYS_DIR)/client_assertion.jwt pronto (LOCAL)"

client-assertion-prod: ensure-jose keys-gen
	@echo "▶ Gerando client_assertion (PROD)"
	$(NODE_BIN) resource-server/scripts/make_client_assertion.mjs \
	  --key $(PRV_PEM) \
	  --kid api-client-demo \
	  --client-id api-client \
	  --aud https://api.greijal.app/kc/realms/api/protocol/openid-connect/token \
	  > $(CLIENT_KEYS_DIR)/client_assertion.jwt
	@echo "OK: $(CLIENT_KEYS_DIR)/client_assertion.jwt pronto (PROD)"

### ===== Nginx =====
reload-nginx-local:
	@echo "▶ Reload Nginx (LOCAL)"
	@if [[ -z "$(GATEWAY_LOCAL)" ]]; then echo "gateway (local) não está rodando"; exit 1; fi
	docker exec $(GATEWAY_LOCAL) nginx -t
	docker exec $(GATEWAY_LOCAL) nginx -s reload

reload-nginx-prod:
	@echo "▶ Reload Nginx (PROD)"
	@if [[ -z "$(GATEWAY_PROD)" ]]; then echo "gateway (prod) não está rodando"; exit 1; fi
	docker exec $(GATEWAY_PROD) nginx -t
	docker exec $(GATEWAY_PROD) nginx -s reload

### ===== Health & Smoke =====
health-local:
	@echo "▶ Health LOCAL"
	@curl -sk https://localhost:8443/kc/realms/api/.well-known/openid-configuration | jq .issuer
	@curl -sk https://localhost:8443/.well-known/api-client.jwks.json | jq '.keys[0].kid'
	@curl -sk https://localhost:8443/api/healthz | jq .

health-prod:
	@echo "▶ Health PROD"
	@curl -sk https://api.greijal.app/kc/realms/api/.well-known/openid-configuration | jq .issuer
	@curl -sk https://api.greijal.app/.well-known/api-client.jwks.json | jq '.keys[0].kid'
	@curl -sk https://api.greijal.app/api/healthz | jq .

smoke-local: client-assertion-local
	@echo "▶ Smoke LOCAL (token + /api/hello)"
	bash resource-server/scripts/curl-example.sh local

smoke-prod: client-assertion-prod
	@echo "▶ Smoke PROD (token + /api/hello)"
	bash resource-server/scripts/curl-example.sh prod

### ===== Postman =====
postman-export:
	@echo "▶ Exportando Postman collection (resource-server/postman/collection.json)"
	@mkdir -p resource-server/postman
	@cp resource-server/postman/collection.template.json resource-server/postman/collection.json
	@echo "Abra no Postman e ajuste variáveis se quiser customizar."

lint:
	@echo "▶ Validando docker-compose e Nginx"
	docker compose -f $(COMPOSE_LOCAL) config >/dev/null && echo "✔ $(COMPOSE_LOCAL) OK"
	docker compose -f $(COMPOSE_PROD)  config >/dev/null && echo "✔ $(COMPOSE_PROD) OK"