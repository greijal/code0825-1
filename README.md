# Resource Server — KC26 — private_key_jwt (SIMPLIFICADO)

Tudo dentro de `resource-server/`. Dois modos: **local** (TLS self-signed) e **prod** (Let's Encrypt externo).

## Como rodar (local)
```bash
make certs         # 1ª vez: gera server.crt/server.key para o Nginx
make up-local      # sobe Postgres + Keycloak + API + Nginx em https://localhost:8443
make health-local  # espera {"status":"ok"}
make oidc-local    # deve imprimir "https://localhost/kc/realms/api"
```

Descoberta OIDC: `https://localhost:8443/kc/realms/api/.well-known/openid-configuration`  
Issuer esperado: `https://localhost/kc/realms/api`

## Como funciona (resumo leigo)
- **JWT** é um “cartão” com dados do cliente assinado digitalmente pelo **Keycloak**. A API só confia no que vem assinado.
- **JWS** = “JWT assinado” (o que usamos). Não é criptografado; é legível, mas **não alterável** (a assinatura quebra).
- **JWE** = “JWT criptografado” (não usamos aqui).
- Fluxo:
  1. O **cliente** pede um token ao **Keycloak** (usando `private_key_jwt`, isto é, assina uma *client_assertion* com sua **chave privada**).
  2. O **Keycloak** emite um **Access Token (JWT)**.
  3. O **cliente** chama a **API** com `Authorization: Bearer <token>`.
  4. A **API** valida: *issuer*, *assinatura (JWKS do Keycloak)*, *tempo (exp/nbf/iat)* e *audience*.

## Validações de segurança (na API)
- **Issuer pin**: `iss` deve ser `https://localhost/kc/realms/api` (ou `https://api.greijal.app/kc/...` no prod).
- **Assinatura**: `JwtDecoder` baixa o **JWKS** do Keycloak e verifica a assinatura RS256.
- **Clock skew**: tolerância de 60s para relógio (iat/nbf/exp).
- **Audience**: exige `aud` contendo `resource-api` (configure um **Audience Mapper** no cliente do Keycloak).
- **Roles**: endpoint `/admin/*` exige `ROLE_ADMIN` (mapear realm-role `ADMIN` para `ROLE_ADMIN` se necessário).

## Estrutura
```
resource-server/
  Dockerfile
  docker-compose.local.yml
  docker-compose.prod.yml
  nginx/
    gateway.local.conf
    gateway.prod.conf
  scripts/
    issue_cert.sh
    fix_cert_perms.sh
    jwks_gen.py
  certs/
    out/                 # server.crt / server.key (self-signed)
  static/.well-known/
    api-client.jwks.json # exemplo de JWKS
  jwks/jwks.json         # fonte do arquivo acima
  keycloak/realms/api-realm.json
  src/main/java/...      # Spring API
  src/main/resources/application.yml
  Makefile
  README.md
```

## Produção (resumo)
- Ajuste DNS para `api.greijal.app`.
- Nginx usa LE em `/etc/letsencrypt/live/api.greijal.app/` (monte do host).
- Keycloak roda sob `/kc`. Issuer esperado: `https://api.greijal.app/kc/realms/api`.
- Compose: `make up-prod` (emita/renove LE fora do projeto com certbot, ou mantenha via Cloudflare Tunnel conforme seu cenário).

## Postman
A coleção está em `postman/collection.json` com:
- `GET https://localhost:8443/api/healthz`
- `GET https://localhost:8443/kc/realms/api/.well-known/openid-configuration`
(Endpoints protegidos requerem Bearer real — você pode colar um access_token obtido pelo seu cliente M2M).

## Dica sobre JWKS do cliente M2M
Se quiser publicar o **JWKS do seu cliente** em `/.well-known/api-client.jwks.json`:
```bash
python3 scripts/jwks_gen.py ./client-keys/public.pem meu-kid-YYYY-MM-DD > jwks/jwks.json
cp jwks/jwks.json static/.well-known/api-client.jwks.json
make reload-nginx-local
```

## License
MIT
