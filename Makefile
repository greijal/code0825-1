# =========================
# Makefile - Gateway Stack
# =========================

.PHONY: up down logs reload-nginx health deps \
        certs certs-public certs-public-copy certs-public-self certs-all \
        build clean-app clean-docker help

DOMAIN             ?= api.greijal.app
LE_DIR             ?= certs/le
SCRIPTS_DIR        ?= scripts
COMPOSE_FILE       ?= docker-compose.yml
ENV_FILE           ?= .env
APP_HEALTH_URL     ?= https://localhost:8443/api/actuator/health
CERTS_PUBLIC_MODE  ?= auto         # auto por padrão (tenta copiar LE; se faltar, gera autoassinado DEV)

MVN := $(shell test -x ./mvnw && echo "./mvnw" || echo "docker run --rm -v $$PWD:/app -v $$HOME/.m2:/root/.m2 -w /app maven:3.9.9-eclipse-temurin-21 mvn")

up: build certs-all
	docker compose --env-file $(ENV_FILE) -f $(COMPOSE_FILE) up -d --build

down:
	docker compose -f $(COMPOSE_FILE) down -v

logs:
	docker compose -f $(COMPOSE_FILE) logs -f --tail=200

reload-nginx:
	docker compose -f $(COMPOSE_FILE) exec -T nginx nginx -t
	docker compose -f $(COMPOSE_FILE) exec -T nginx nginx -s reload

health:
	curl -sk "$(APP_HEALTH_URL)" | jq . || { echo "Falha no health-check"; exit 1; }

build:
	$(MVN) -B -DskipTests clean package spring-boot:repackage
	@JAR=$$(ls target/*.jar | grep -v original | grep -v plain | head -n 1); \
	 test -n "$$JAR" || { echo "ERRO: não encontrei JAR em target/"; exit 2; }; \
	 cp "$$JAR" target/app.jar

clean-app:
	rm -f target/app.jar || true
	$(MVN) -B clean

certs:
	bash $(SCRIPTS_DIR)/create_cert.sh

certs-public:
	bash $(SCRIPTS_DIR)/gen_public_cert.sh --domain $(DOMAIN) --mode $(CERTS_PUBLIC_MODE) --out-dir $(LE_DIR)

certs-public-copy:
	bash $(SCRIPTS_DIR)/gen_public_cert.sh --domain $(DOMAIN) --mode copy --out-dir $(LE_DIR)

certs-public-self:
	bash $(SCRIPTS_DIR)/gen_public_cert.sh --domain $(DOMAIN) --mode self --out-dir $(LE_DIR)

certs-all: certs certs-public
	@echo "OK: certificados internos + público prontos."

deps:
	@which openssl >/dev/null 2>&1 || { echo "Aviso: openssl não encontrado (necessário)"; true; }
	@which jq >/dev/null 2>&1 || { echo "Aviso: jq não encontrado (recomendado)"; true; }

clean-docker:
	docker image prune -f
	docker builder prune -f

help:
	@echo "Alvos: up, down, logs, reload-nginx, health, build, clean-app, certs, certs-public, certs-public-copy, certs-public-self, certs-all, deps, clean-docker"