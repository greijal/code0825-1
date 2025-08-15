.PHONY: up-local down-local logs-local health-local oidc-local certs reload-nginx-local up-prod down-prod logs-prod deps

PYTHON ?= python3
PIP ?= $(PYTHON) -m pip
PRE_COMMIT_PKG ?= pre-commit
CHECKSTYLE_VERSION := 11.0.0
CHECKSTYLE_NAME := checkstyle-$(CHECKSTYLE_VERSION)
CHECKSTYLE_JAR := $(CHECKSTYLE_NAME)-all.jar
CHECKSTYLE_URL := https://github.com/checkstyle/checkstyle/releases/download/$(CHECKSTYLE_NAME)/$(CHECKSTYLE_JAR)
MVN := $(shell test -x ./mvnw && echo "./mvnw" || echo "docker run --rm -v $$PWD:/app -v $$HOME/.m2:/root/.m2 -w /app maven:3.9.9-eclipse-temurin-21 mvn")

deps:
	$(PIP) install $(PRE_COMMIT_PKG)
	@if [ ! -f "$(CHECKSTYLE_JAR)" ]; then \
		echo "Baixando $(CHECKSTYLE_JAR) ..."; \
		curl -fL -o "$(CHECKSTYLE_JAR)" "$(CHECKSTYLE_URL)"; \
	else \
		echo "$(CHECKSTYLE_JAR) já existe. Pulando download."; \
	fi

certs:
	bash scripts/create_cert.sh

up:
	$(MVN) -B -DskipTests clean package spring-boot:repackage
	JAR=$$(ls target/*.jar | grep -v original | grep -v plain | head -n 1); \
	cp "$$JAR" target/app.jar
	docker compose --env-file .env -f docker-compose.yml up -d --build

down:
	docker compose -f docker-compose.yml down -v

logs:
	docker compose -f docker-compose.yml logs -f --tail=200

reload-nginx:
	ctr=$$(docker compose -f docker-compose.yml ps -q gateway); \
	if [ -z "$$ctr" ]; then echo "gateway não está em execução"; exit 1; fi; \
	docker exec $$ctr nginx -t && docker exec $$ctr nginx -s reload

health:
	curl -sk https://localhost:8443/actuator/health | jq . || { echo "Falha no health-check"; exit 1; }