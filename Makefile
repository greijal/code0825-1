    .PHONY: up-local logs-local reload-nginx-local health-local up-prod down-prod logs-prod reload-nginx-prod health-prod

    # ===== LOCAL =====
    up-local:
    	@echo "▶ Subindo LOCAL (https://localhost:8443)"
    	docker compose -f docker-compose.local.yml up -d --build

    logs-local:
    	@echo "▶ Logs LOCAL (Ctrl+C para sair)"
    	docker compose -f docker-compose.local.yml logs -f --tail=200

    reload-nginx-local:
    	@echo "▶ Reload Nginx (local)"
    	docker exec $$(docker compose -f docker-compose.local.yml ps -q gateway) nginx -t && \
	docker exec $$(docker compose -f docker-compose.local.yml ps -q gateway) nginx -s reload

    health-local:
    	@echo "▶ Health LOCAL"
    	curl -sk https://localhost:8443/api/healthz | jq . || true

    # ===== PROD =====
    up-prod:
    	@echo "▶ Subindo PROD (https://api.greijal.app)"
    	docker compose -f docker-compose.prod.yml up -d --build

    down-prod:
    	@echo "▶ Derrubando PROD"
    	docker compose -f docker-compose.prod.yml down

    logs-prod:
    	@echo "▶ Logs PROD (Ctrl+C para sair)"
    	docker compose -f docker-compose.prod.yml logs -f --tail=200

    reload-nginx-prod:
    	@echo "▶ Reload Nginx (prod)"
    	docker exec $$(docker compose -f docker-compose.prod.yml ps -q gateway) nginx -t && \
	docker exec $$(docker compose -f docker-compose.prod.yml ps -q gateway) nginx -s reload

    health-prod:
    	@echo "▶ Health PROD"
    	curl -sk https://api.greijal.app/api/healthz | jq . || true
