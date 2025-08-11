# Ultra Simple S2S — KC26 — Private Key JWT (JWKS auto)

Tudo em um único projeto, com **Makefile** automatizando:
- geração de **TLS self‑signed** para o Nginx (origem local e prod),
- geração/publicação do **JWKS** do *cliente S2S*,
- geração do **client_assertion (private_key_jwt)**,
- *smoke test* (token + chamada `/api/hello`),
- coleção do **Postman**.

## Como funciona (versão para humanos)
1. O **cliente S2S** possui um par de chaves: `private.pem` (segredo) e `public.pem` (pode ser público).
2. A partir do **public.pem**, publicamos um **JWKS** (JSON com a chave pública) no gateway:  
   `/.well-known/api-client.jwks.json`.
3. Para pegar token, o cliente assina um **JWT de autenticação** (`client_assertion`) com a **private.pem**.
4. O Keycloak valida a assinatura usando o **JWKS** publicado. Se ok, emite o **access_token (JWT)**.
5. A API valida esse access token (issuer + assinatura) e autoriza o acesso.

Sem HMAC/JWE: limpo e simples, só **private_key_jwt + access token JWT**.

---

## Requisitos
- Docker / Docker Compose
- OpenSSL (para chaves/certs)
- Node.js (para gerar `client_assertion` — o `Makefile` instala `jose` localmente)
- Python 3 (para script simples e `jq` no health)

## Subir LOCAL (https://localhost:8443)
```bash
make up-local
make client-assertion-local
make smoke-local       # token + chamada /api/hello
make postman-export    # gera resource-server/postman/collection.json
```

## Subir PROD (api.greijal.app)
> Use Cloudflare Tunnel (No TLS Verify no origin) ou aponte DNS direto.
```bash
make up-prod
make client-assertion-prod
make smoke-prod
make postman-export
```

## Publicar JWKS — automatizado
- **Local**: `make jwks-publish-local` (rodado automaticamente no `make up-local`)
- **Prod**:  `make jwks-publish-prod`  (rodado automaticamente no `make up-prod`)

O arquivo é servido em:
- Local: `https://localhost:8443/.well-known/api-client.jwks.json`
- Prod:  `https://api.greijal.app/.well-known/api-client.jwks.json`

## Keycloak — ajustes (UI)
- **Clients → api-client**
  - *Client Authentication* = ON
  - *Client Authenticator* = **Signed JWT**
  - *Service Accounts* = ON
  - *Standard Flow* = OFF; *Direct Access Grants* = OFF
  - **Keys**: aponte para o **JWKS URL**:
    - Local: `https://localhost:8443/.well-known/api-client.jwks.json`
    - Prod:  `https://api.greijal.app/.well-known/api-client.jwks.json`
- *Realm Settings → Tokens*: `Access Token Lifespan` ~ 5 min

Issuer esperado:
- Local: `https://localhost/kc/realms/api`
- Prod:  `https://api.greijal.app/kc/realms/api`

## Gerar chaves do cliente & JWKS
```bash
make keys-gen     # cria resource-server/client-keys/private.pem e public.pem (se faltarem)
make jwks-gen     # gera resource-server/client-keys/jwks.json
# publicar:
make jwks-publish-local   # ou: make jwks-publish-prod
```

## Gerar client_assertion (private_key_jwt)
```bash
make client-assertion-local   # aud local
# ou
make client-assertion-prod    # aud prod
# arquivo gerado: resource-server/client-keys/client_assertion.jwt
```

## Teste rápido (curl)
```bash
make smoke-local   # local
# ou
make smoke-prod    # prod
```

## Postman
- Importar `resource-server/postman/collection.json`
- Variáveis: `base_url`, `token_url`, `client_id`, `client_assertion`

## Estrutura
```
.
├─ Makefile
├─ docker-compose.local.yml
├─ docker-compose.prod.yml
├─ nginx/
│  ├─ gateway.local.conf
│  ├─ gateway.prod.conf
│  └─ includes/proxy_headers.conf
├─ certs/
│  ├─ 01-generate-ca.sh
│  └─ 02-generate-server.sh
└─ resource-server/
   ├─ Dockerfile
   ├─ pom.xml
   ├─ static/.well-known/        (JWKS publicado aqui)
   ├─ client-keys/               (private.pem/public.pem/jwks.json/client_assertion.jwt)
   ├─ scripts/
   │  ├─ jwks_gen.py
   │  ├─ make_client_assertion.mjs
   │  └─ curl-example.sh
   ├─ postman/collection.template.json
   ├─ keycloak/realms/api-realm.json
   └─ src/main/...
```

## Dicas de segurança
- Proteja o acesso ao Admin Console do Keycloak atrás do seu SSO/Access.
- Rotacione periodicamente a **private.pem**; gere novo **kid** e publique novo JWKS.
- Mantenha o **access token** curto (ex.: 5 min).
- Valide **issuer** e **algoritmo** no resource-server (já configurado).