# =========================
# Makefile - Gateway Stack
# =========================

.PHONY: up down logs reload-nginx health deps \
        certs certs-public certs-public-copy certs-public-self certs-all \
        build clean-app clean-docker help

COMPOSE_FILE       ?= docker-compose.yml
ENV_FILE           ?= .env
APP_HEALTH_URL     ?= http://localhost/api/actuator/health

# Paths and cert/keystore defaults
KEYCLOAK_CONF_DIR  ?= keycloak/conf
KEYSTORE_FILE      ?= $(KEYCLOAK_CONF_DIR)/server.keystore
KEYSTORE_PASSWORD  ?= password
CERT_PUBLIC_FILE   ?= $(KEYCLOAK_CONF_DIR)/server.crt
KEY_ALIAS          ?= server

MVN := $(shell test -x ./mvnw && echo "./mvnw" || echo "docker run --rm -v $$PWD:/app -v $$HOME/.m2:/root/.m2 -w /app maven:3.9.9-eclipse-temurin-21 mvn")

up:
	docker compose --env-file $(ENV_FILE) -f $(COMPOSE_FILE) up -d --build

down:
	docker compose -f $(COMPOSE_FILE) down -v

logs:
	docker compose -f $(COMPOSE_FILE) logs -f --tail=200

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

clean-docker:
	docker image prune -f
	docker builder prune -f

certs:
	@bash ./scripts/certs.sh "$(KEYSTORE_FILE)" "$(KEYSTORE_PASSWORD)" "$(KEY_ALIAS)"

certs-public:
	@bash ./scripts/certs-public.sh "$(KEYSTORE_FILE)" "$(KEYSTORE_PASSWORD)" "$(KEY_ALIAS)" "$(CERT_PUBLIC_FILE)"

certs-all: certs certs-public


help:
	@echo "Alvos: up, down, logs, reload-nginx, health, build, clean-app, certs, certs-public, certs-all, deps, clean-docker"