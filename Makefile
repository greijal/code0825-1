    .PHONY: up-local down-local logs-local health-local oidc-local certs reload-nginx-local up-prod down-prod logs-prod

    certs:
    	bash scripts/issue_cert.sh && bash scripts/fix_cert_perms.sh

    up-local:
    	docker compose -f docker-compose.local.yml up -d --build

    down-local:
    	docker compose -f docker-compose.local.yml down -v

    logs-local:
    	docker compose -f docker-compose.local.yml logs -f --tail=200

    reload-nginx-local:
    	docker exec $$(docker compose -f docker-compose.local.yml ps -q gateway) nginx -t && \
	docker exec $$(docker compose -f docker-compose.local.yml ps -q gateway) nginx -s reload

    health-local:
    	curl -sk https://localhost:8443/api/healthz | jq . || true

    oidc-local:
    	curl -sk https://localhost:8443/kc/realms/api/.well-known/openid-configuration | jq .issuer || true

    up-prod:
    	docker compose -f docker-compose.prod.yml up -d --build

    down-prod:
    	docker compose -f docker-compose.prod.yml down -v

    logs-prod:
    	docker compose -f docker-compose.prod.yml logs -f --tail=200
