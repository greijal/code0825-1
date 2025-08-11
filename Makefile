# Usa o Maven Wrapper se existir; caso contrário, usa Maven via Docker
MVN := $(shell test -x ./mvnw && echo "./mvnw" || echo "docker run --rm -v $$PWD:/app -v $$HOME/.m2:/root/.m2 -w /app maven:3.9.9-eclipse-temurin-21 mvn")

.PHONY: up-local down-local logs-local health-local oidc-local certs reload-nginx-local up-prod down-prod logs-prod

certs:
	bash scripts/issue_cert.sh && bash scripts/fix_cert_perms.sh

up-local:
	$(MVN) -B -DskipTests clean package spring-boot:repackage
	JAR=$$(ls target/*.jar | grep -v original | grep -v plain | head -n 1); \
	cp "$$JAR" target/app.jar
	docker compose --env-file .env -f docker-compose.local.yml up -d --build

down-local:
	docker compose -f docker-compose.local.yml down -v

logs-local:
	docker compose -f docker-compose.local.yml logs -f --tail=200

reload-nginx-local:
	ctr=$$(docker compose -f docker-compose.local.yml ps -q gateway); \
	if [ -z "$$ctr" ]; then echo "gateway não está em execução"; exit 1; fi; \
	docker exec $$ctr nginx -t && docker exec $$ctr nginx -s reload

health-local:
	curl -sk https://localhost:8443/api/actuator/health | jq . || { echo "Falha no health-check"; exit 1; }

oidc-local:
	curl -sk https://localhost:8443/kc/realms/api/.well-known/openid-configuration | jq .issuer || { echo "Falha ao obter OIDC (verifique se jq e curl estão instalados)"; true; }

up-prod:
	$(MVN) -B -DskipTests clean package spring-boot:repackage
	JAR=$$(ls target/*.jar | grep -v original | grep -v plain | head -n 1); \
	cp "$$JAR" target/app.jar
	docker compose --env-file .env.prod -f docker-compose.prod.yml up -d --build

down-prod:
	docker compose -f docker-compose.prod.yml down -v

logs-prod:
	docker compose -f docker-compose.prod.yml logs -f --tail=200
