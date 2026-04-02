# MCP Auth Flow: Auth0 + Claude Desktop

This guide traces the complete OAuth 2.1 flow when Claude Desktop (`mcp-remote`) connects to the Apollo MCP Server using Auth0 as the identity provider. It covers every HTTP exchange and the configuration changes required across all four components.

- [MCP Auth Flow: Auth0 + Claude Desktop](#mcp-auth-flow-auth0--claude-desktop)
  - [Architecture Overview](#architecture-overview)
  - [Key Difference from Built-in Auth: No CIMD](#key-difference-from-built-in-auth-no-cimd)
  - [Pre-requisites: Auth0 Setup](#pre-requisites-auth0-setup)
  - [Wire-Level Flow](#wire-level-flow)
    - [Step 1 — Unauthenticated request returns 401](#step-1--unauthenticated-request-returns-401)
    - [Step 2 — Fetch Protected Resource Metadata](#step-2--fetch-protected-resource-metadata)
    - [Step 3 — Fetch Auth0 OIDC discovery](#step-3--fetch-auth0-oidc-discovery)
    - [Step 4 — Authorization request (browser opens)](#step-4--authorization-request-browser-opens)
    - [Step 5 — Auth0 redirects back with code](#step-5--auth0-redirects-back-with-code)
    - [Step 6 — Token exchange](#step-6--token-exchange)
    - [Step 7 — JWT from Auth0 decoded](#step-7--jwt-from-auth0-decoded)
    - [Step 8 — Authenticated MCP request](#step-8--authenticated-mcp-request)
  - [Configuration Reference](#configuration-reference)
  - [Comparison: Built-in Auth vs Auth0](#comparison-built-in-auth-vs-auth0)
  - [Troubleshooting](#troubleshooting)

## Architecture Overview

```
Claude Desktop                 Apollo MCP Server            Auth0                    Apollo Router
(mcp-remote)                   (Kubernetes pod)        (your-tenant.auth0.com)      (Kubernetes pod)
     |                               |                           |                         |
     |-- POST /mcp (no token) ------>|                           |                         |
     |<-- 401 + resource_metadata ---|                           |                         |
     |                               |                           |                         |
     |-- GET /.well-known/oauth-protected-resource/mcp -------->|                         |
     |<-- { authorization_servers: ["https://...auth0.com"] } --|                         |
     |                               |                           |                         |
     |-- GET /.well-known/openid-configuration ----------------------------------------->|
     |<-- OIDC discovery (no client_id_metadata_document_supported) --------------------|  |
     |                               |                           |                         |
     |   [browser → Auth0 Universal Login] ---------------------->                         |
     |<-- 302 /callback?code=... --------------------------------|                         |
     |                               |                           |                         |
     |-- POST /oauth/token (code + code_verifier) --------------->|                        |
     |<-- { access_token: JWT } ----------------------------------|                        |
     |                               |                           |                         |
     |-- POST /mcp + Bearer -------->|                           |                         |
     |                               |-- GET /jwks.json -------->|                         |
     |                               |-- POST /graphql + Bearer -|-----------------------> |
     |                               |                           |   validate JWT          |
     |                               |                           |   enforce @requiresScopes
     |<-- tool results --------------|                           |                         |
```

## Key Difference from Built-in Auth: No CIMD

The built-in authorization server (users subgraph) supports [Client ID Metadata Documents](mcp-production.md#client-registration-approach) — a client can use an HTTPS URL as its `client_id`, and the server fetches the metadata document automatically. No pre-registration is needed.

**Auth0 does not support CIMD.** Its OIDC discovery document does not advertise `client_id_metadata_document_supported`, and it will not fetch a URL passed as `client_id`. As a result:

- Claude Desktop (`mcp-remote`) must use a **pre-registered string `client_id`** (e.g., `abc123XYZ`) issued by Auth0
- You must register the client in the Auth0 dashboard before the flow can work
- The `--client-id` flag must be passed to `mcp-remote` in the Claude Desktop config

Everything else — PKCE, authorization code flow, JWT validation — works the same way.

## Pre-requisites: Auth0 Setup

Before running the flow, complete these steps in the Auth0 dashboard.

### 1. Create an Application

Go to **Applications > Create Application**, select **Single Page Application**, and note the generated **Client ID** (e.g., `abc123XYZ`).

In the **Settings** tab, configure:

| Field | Value |
|-------|-------|
| **Allowed Callback URLs** | `http://127.0.0.1:*/callback` |
| **Allowed Web Origins** | `http://127.0.0.1` |

> `mcp-remote` picks a random local port on each run, so the wildcard `*` is needed. If your Auth0 plan does not allow wildcards, add a fixed port (e.g., `http://127.0.0.1:54321/callback`) and pass `--callback-port 54321` to `mcp-remote`.

### 2. Create an API

Go to **Applications > APIs > Create API**:

| Field | Value |
|-------|-------|
| **Name** | Apollo MCP Server |
| **Identifier** | `https://mcp.yourdomain.com` |

This identifier becomes the `aud` claim in the access token and must match `audiences` in `mcp.yaml`.

Under the **Permissions** tab, add:

| Permission | Description |
|------------|-------------|
| `user:read:email` | Read user email addresses |

### 3. Note your tenant domain

Your Auth0 tenant domain (e.g., `your-tenant.auth0.com`) is the issuer URL used throughout the config below.

## Wire-Level Flow

### Step 1 — Unauthenticated request returns 401

`mcp-remote` sends `initialize` without a token. With `allow_anonymous_mcp_discovery: true`, MCP discovery methods succeed, but any tool call triggers:

```http
HTTP/1.1 401 Unauthorized
WWW-Authenticate: Bearer resource_metadata="https://mcp.yourdomain.com/.well-known/oauth-protected-resource",
                         scope="user:read:email"
```

`mcp-remote` extracts the `resource_metadata` URL and begins discovery.

### Step 2 — Fetch Protected Resource Metadata

```http
GET /.well-known/oauth-protected-resource/mcp HTTP/1.1
Host: mcp.yourdomain.com
```

```json
{
  "resource": "https://mcp.yourdomain.com/mcp",
  "authorization_servers": ["https://your-tenant.auth0.com"],
  "scopes_supported": ["user:read:email"],
  "bearer_methods_supported": ["header"]
}
```

The `authorization_servers` array points `mcp-remote` to Auth0 as the issuer.

### Step 3 — Fetch Auth0 OIDC discovery

`mcp-remote` checks `/.well-known/oauth-authorization-server` first (RFC 8414), then falls back to `/.well-known/openid-configuration` (OIDC). Auth0 serves the latter:

```http
GET /.well-known/openid-configuration HTTP/1.1
Host: your-tenant.auth0.com
```

```json
{
  "issuer": "https://your-tenant.auth0.com/",
  "authorization_endpoint": "https://your-tenant.auth0.com/authorize",
  "token_endpoint": "https://your-tenant.auth0.com/oauth/token",
  "jwks_uri": "https://your-tenant.auth0.com/.well-known/jwks.json",
  "response_types_supported": ["code"],
  "grant_types_supported": ["authorization_code", "refresh_token"],
  "code_challenge_methods_supported": ["S256"],
  "scopes_supported": ["openid", "profile", "email", "offline_access"]
}
```

Notice: no `client_id_metadata_document_supported`. `mcp-remote` falls back to using the pre-registered string `client_id`.

### Step 4 — Authorization request (browser opens)

`mcp-remote` generates a PKCE pair:

```text
code_verifier  = "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk"
code_challenge = "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM"
method         = "S256"
```

It spins up a local HTTP listener (e.g., port 54321) and opens the system browser:

```http
GET /authorize
  ?response_type=code
  &client_id=abc123XYZ
  &redirect_uri=http%3A%2F%2F127.0.0.1%3A54321%2Fcallback
  &scope=openid+user%3Aread%3Aemail
  &audience=https%3A%2F%2Fmcp.yourdomain.com
  &state=random-csrf-state
  &code_challenge=E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM
  &code_challenge_method=S256 HTTP/1.1
Host: your-tenant.auth0.com
```

Two parameters that differ from the built-in flow:

- `client_id` is a **string**, not a URL — no metadata document is fetched
- `audience` is required by Auth0 — without it, Auth0 issues an opaque token instead of a JWT, which the MCP server cannot validate

The user sees Auth0's Universal Login page. On success, Auth0 redirects to the local callback.

### Step 5 — Auth0 redirects back with code

```http
HTTP/1.1 302 Found
Location: http://127.0.0.1:54321/callback
  ?code=opaque_auth_code_from_auth0
  &state=random-csrf-state
```

`mcp-remote`'s local server catches the callback and extracts the authorization code.

### Step 6 — Token exchange

```http
POST /oauth/token HTTP/1.1
Host: your-tenant.auth0.com
Content-Type: application/x-www-form-urlencoded

grant_type=authorization_code
  &code=opaque_auth_code_from_auth0
  &redirect_uri=http%3A%2F%2F127.0.0.1%3A54321%2Fcallback
  &client_id=abc123XYZ
  &code_verifier=dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk
```

Auth0 verifies the PKCE challenge and returns:

```json
{
  "access_token": "eyJhbGciOiJSUzI1NiIsImtpZCI6InNvbWUta2lkIn0...",
  "id_token": "eyJhbGciOiJSUzI1NiIsImtpZCI6InNvbWUta2lkIn0...",
  "token_type": "Bearer",
  "expires_in": 86400,
  "scope": "openid user:read:email"
}
```

Auth0 also returns an `id_token` (OIDC). Only `access_token` is forwarded to the MCP server.

### Step 7 — JWT from Auth0 decoded

Header:

```json
{
  "alg": "RS256",
  "kid": "auth0-signing-key-id",
  "typ": "JWT"
}
```

Payload:

```json
{
  "iss": "https://your-tenant.auth0.com/",
  "sub": "auth0|64abc123def456",
  "aud": "https://mcp.yourdomain.com",
  "iat": 1710000000,
  "exp": 1710086400,
  "scope": "openid user:read:email",
  "azp": "abc123XYZ"
}
```

Differences from the built-in JWT:

| Claim | Built-in | Auth0 |
|-------|----------|-------|
| `alg` | `ES256` | `RS256` (default; configurable) |
| `sub` | `user:1` | `auth0\|<opaque-id>` |
| `aud` | `apollo-mcp` | Your API Identifier URL |
| `iss` | `http://localhost:4001` | `https://your-tenant.auth0.com/` (trailing slash) |
| `kid` | `main-key-2024` | Rotating Auth0 key ID |

> The trailing slash on `iss` is Auth0-specific. Ensure the Router's JWT validation does not do an exact string match on the issuer — most JWT libraries handle this correctly, but it is worth verifying.

### Step 8 — Authenticated MCP request

`mcp-remote` stores the token and attaches it to subsequent requests:

```http
POST /mcp HTTP/1.1
Host: mcp.yourdomain.com
Authorization: Bearer eyJhbGciOiJSUzI1NiIs...
Content-Type: application/json

{
  "jsonrpc": "2.0",
  "method": "tools/call",
  "params": {
    "name": "myProfileDetails",
    "arguments": {}
  },
  "id": 2
}
```

The Apollo MCP Server:
1. Fetches Auth0's JWKS (`https://your-tenant.auth0.com/.well-known/jwks.json`)
2. Verifies the RS256 signature using the key matching `kid`
3. Checks `aud` matches `https://mcp.yourdomain.com`
4. Checks `scope` contains `user:read:email`
5. Forwards the same Bearer token to the Router

The Router independently repeats steps 1–3 before executing the GraphQL query and enforcing `@requiresScopes` directives.

## Configuration Reference

### `deploy/apollo-mcp-server/mcp.yaml`

```yaml
endpoint: http://reference-architecture-dev.apollo.svc.cluster.local:80

transport:
  type: streamable_http
  port: 8000
  host_validation:
    enabled: true
    allowed_hosts:
      - "mcp.yourdomain.com"
  auth:
    servers:
      - https://your-tenant.auth0.com    # Auth0 issuer (with or without trailing slash)
    audiences:
      - https://mcp.yourdomain.com       # Must match the Auth0 API Identifier exactly
    allow_any_audience: false
    resource: https://mcp.yourdomain.com/mcp
    scopes:
      - user:read:email
    scope_mode: require_any
    allow_anonymous_mcp_discovery: true

logging:
  level: info
```

### `deploy/operator-resources/supergraph-dev.yaml` — Router JWT config

```yaml
routerConfig:
  authentication:
    router:
      jwt:
        jwks:
          - url: https://your-tenant.auth0.com/.well-known/jwks.json
  authorization:
    directives:
      enabled: true
```

### Claude Desktop `~/Library/Application Support/Claude/claude_desktop_config.json`

```json
{
  "mcpServers": {
    "apollo": {
      "command": "npx",
      "args": [
        "mcp-remote",
        "https://mcp.yourdomain.com/mcp",
        "--client-id", "abc123XYZ"
      ]
    }
  }
}
```

The `--client-id` flag passes the pre-registered Auth0 Application Client ID to `mcp-remote`. Without it, `mcp-remote` attempts dynamic client registration (RFC 7591), which Auth0's management endpoint requires a separate bearer token to use — that path will fail.

## Comparison: Built-in Auth vs Auth0

| Aspect | Built-in (users subgraph) | Auth0 |
|--------|--------------------------|-------|
| Client registration | Automatic via CIMD (URL as `client_id`) | Manual — pre-register in Auth0 dashboard |
| `client_id` format | HTTPS URL | Opaque string (`abc123XYZ`) |
| `--client-id` flag in mcp-remote | Not needed | Required |
| Discovery endpoint | RFC 8414 (`oauth-authorization-server`) | OIDC (`openid-configuration`) |
| Login UI | Custom form (users subgraph) | Auth0 Universal Login |
| Token signing algorithm | ES256 | RS256 (default) |
| `aud` claim value | `apollo-mcp` | Auth0 API Identifier URL |
| `sub` format | `user:1` | `auth0\|<opaque-id>` |
| `iss` trailing slash | No | Yes (`https://tenant.auth0.com/`) |
| Refresh tokens | Not implemented (demo) | Supported (`offline_access` scope) |
| Token lifetime | 2 hours (demo) | Configurable per tenant/API |

## Troubleshooting

### `mcp-remote` opens browser but redirects to a dead local port

Auth0 redirected to a port that `mcp-remote` is no longer listening on. This happens if the `mcp-remote` process restarted between opening the browser and completing the callback. Restart Claude Desktop and try again.

If it happens consistently, pin a fixed callback port:

```json
"args": ["mcp-remote", "https://mcp.yourdomain.com/mcp",
         "--client-id", "abc123XYZ",
         "--callback-port", "54321"]
```

Then add `http://127.0.0.1:54321/callback` to Auth0's Allowed Callback URLs.

### `invalid_token` — audience mismatch

The `aud` claim in the token does not match `audiences` in `mcp.yaml`. Check:

1. The `audience` parameter in the authorization request matches the Auth0 API Identifier exactly
2. `mcp.yaml` `audiences` value matches the same API Identifier
3. The API exists in Auth0 and is enabled for the Application

### `invalid_token` — issuer mismatch

Auth0 appends a trailing slash to the issuer (`https://your-tenant.auth0.com/`). If the Router is doing a strict string comparison, it may reject tokens where `iss` has a trailing slash. Set the JWKS URL explicitly rather than relying on issuer-based discovery:

```yaml
authentication:
  router:
    jwt:
      jwks:
        - url: https://your-tenant.auth0.com/.well-known/jwks.json
```

### `403 Forbidden` — scope missing from token

The `scope` claim does not include `user:read:email`. Verify:

1. The permission `user:read:email` exists in the Auth0 API under **Permissions**
2. The Authorization request includes `scope=openid user:read:email`
3. The Auth0 Application has been granted access to the API

### Token appears but MCP tools return empty results

The Router is receiving the token but `@requiresScopes` directives are blocking field resolution. Decode the JWT at [jwt.io](https://jwt.io) and confirm the `scope` claim contains the expected values. Then verify the Router's `authorization.directives.enabled: true` is set and that JWKS validation is succeeding (check Router logs for JWT errors).
