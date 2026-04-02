# MCP Server: Production Guide

This guide covers deploying the Apollo MCP Server in production with a real OAuth 2.1 identity provider, replacing the demo auto-approval flow used in local development.

- [MCP Server: Production Guide](#mcp-server-production-guide)
  - [Architecture Overview](#architecture-overview)
  - [What Changes from Local Dev](#what-changes-from-local-dev)
  - [Step 1: Choose an Identity Provider](#step-1-choose-an-identity-provider)
  - [Step 2: Configure the Identity Provider](#step-2-configure-the-identity-provider)
  - [Step 3: Configure the Apollo MCP Server](#step-3-configure-the-apollo-mcp-server)
  - [Step 4: Configure the Apollo Router](#step-4-configure-the-apollo-router)
  - [Step 5: Deploy](#step-5-deploy)
  - [Security Considerations](#security-considerations)
  - [Scope Strategy](#scope-strategy)
  - [Per-Operation Scope Requirements](#per-operation-scope-requirements)
  - [Networking and DNS](#networking-and-dns)
  - [Troubleshooting](#troubleshooting)
  - [CIMD Auth Flow: Wire-Level Walkthrough](#cimd-auth-flow-wire-level-walkthrough)

## Architecture Overview

In production, a dedicated identity provider (IdP) handles authentication and token issuance. The MCP server validates tokens from the IdP and forwards them to the Router. The Router independently validates the same tokens and enforces authorization directives.

```
MCP Client                   MCP Server              Identity Provider       Router
    |                            |                          |                    |
    |-- discover auth server --->|                          |                    |
    |<-- IdP URL ----------------|                          |                    |
    |                            |                          |                    |
    |-- OAuth 2.1 flow (PKCE) ----------------------->|                         |
    |<-- access token (JWT) --------------------------|                         |
    |                            |                          |                    |
    |-- POST /mcp + Bearer ----->|                          |                    |
    |                            |-- validate JWT (JWKS) -->|                    |
    |                            |-- GraphQL + Bearer ------|---------------->   |
    |                            |                          |  validate JWT      |
    |                            |                          |  enforce @auth     |
    |<-- tool results -----------|                          |                    |
```

## What Changes from Local Dev

| Aspect | Local Dev | Production |
|--------|-----------|------------|
| Identity Provider | Users subgraph (built-in OAuth endpoints) | External IdP (Auth0, Okta, Keycloak, etc.) |
| Authorization | Login form on users subgraph (any non-empty password) | Real user login via IdP consent screen |
| Token Issuance | In-memory auth codes, local key signing | IdP-managed token lifecycle |
| Client Registration | Client ID Metadata Documents + Dynamic (RFC 7591) fallback | Pre-registered in IdP dashboard or Client ID Metadata Documents |
| HTTPS | Not required (localhost) | Required for all endpoints |
| DNS | `/etc/hosts` workaround for port-forward | Real DNS records |
| Host Validation | Disabled | Enabled with explicit allowed hosts |

## Step 1: Choose an Identity Provider

The Apollo MCP Server requires an OAuth 2.1-compliant IdP that supports:

- **Authorization Code flow with PKCE** (required by the MCP specification)
- **JWT access tokens** with configurable claims (`aud`, `scope`, `sub`)
- **JWKS endpoint** for token signature verification
- **OAuth 2.0 Authorization Server Metadata** (RFC 8414) or **OpenID Connect Discovery**

Tested providers:

| Provider | Discovery | Notes |
|----------|-----------|-------|
| [Auth0](https://auth0.com) | OIDC | See [Apollo's Auth0 guide](https://www.apollographql.com/docs/apollo-mcp-server/guides/auth-auth0) |
| [Okta](https://www.okta.com) | OIDC | Supports custom authorization servers |
| [Keycloak](https://www.keycloak.org) | OIDC | Self-hosted, good for air-gapped environments |
| [Microsoft Entra ID](https://www.microsoft.com/security/business/identity-access/microsoft-entra-id) | OIDC | Azure-native |
| [Google Identity](https://developers.google.com/identity) | OIDC | Limited scope customization |

## Step 2: Configure the Identity Provider

### Create an Application/Client

In your IdP, create a new application with these settings:

- **Application type:** Single Page Application or Native (public client)
- **Grant type:** Authorization Code with PKCE
- **Redirect URIs:** Add the callback URLs for your MCP clients (see provider-specific examples below)
- **Allowed Logout URIs:** Add any post-logout redirect URLs your clients need
- **Scopes:** Define custom scopes that match your GraphQL authorization requirements

#### Auth0

1. Go to **Applications > Create Application**, select **Single Page Application**, and click **Create**.

2. In the **Settings** tab, configure these fields:

   | Field | Value | Notes |
   |-------|-------|-------|
   | **Allowed Callback URLs** | `https://mcp-client.yourdomain.com/callback` | The URL your MCP client redirects to after authorization. For `mcp-remote` during local testing, add `http://localhost:<port>/callback` and `http://127.0.0.1:<port>/callback` as additional entries. |
   | **Allowed Logout URLs** | `https://mcp-client.yourdomain.com` | Optional — needed only if your client supports logout flows. |
   | **Allowed Web Origins** | `https://mcp-client.yourdomain.com` | Required for silent token refresh via CORS. |

   > **Local testing:** You can add `http://localhost` entries alongside production URLs. Auth0 accepts comma-separated lists. Remove localhost entries before going live.

3. Under **Advanced Settings > Grant Types**, ensure **Authorization Code** is enabled (PKCE is automatic for SPAs in Auth0).

4. Note the **Domain** (e.g., `your-tenant.auth0.com`) and **Client ID** from the top of the Settings page.

5. To define custom scopes, go to **Applications > APIs**, select your API (or create one), and add scopes under the **Permissions** tab. Enter each scope as a **Permission** value with a description:

   | Permission (Scope) | Description |
   |--------------------|-------------|
   | `user:read:email` | Read user email addresses |
   | `inventory:read` | Read inventory levels |
   | `order:read` | Read order data |
   | `cart:write` | Modify shopping cart |

   The **Identifier** you set for the API becomes the `audience` value used in token requests and `mcp.yaml`.

For a complete walkthrough, see [Apollo's Auth0 guide](https://www.apollographql.com/docs/apollo-mcp-server/guides/auth-auth0).

#### Okta

1. Go to **Applications > Create App Integration**, select **OIDC** and **Single-Page Application**.

2. Configure:
   - **Sign-in redirect URIs:** `https://mcp-client.yourdomain.com/callback`
   - **Sign-out redirect URIs:** `https://mcp-client.yourdomain.com` (optional)
   - **Controlled access:** Assign to the relevant groups or allow everyone

   > **Local testing:** Add `http://localhost:<port>/callback` as an additional redirect URI during development.

3. To define scopes, go to **Security > API > Authorization Servers**, select your server (or use `default`), and add scopes under the **Scopes** tab. The authorization server's **Issuer URI** is your IdP URL.

#### Keycloak

1. Go to your realm, then **Clients > Create client**. Set the client type to **OpenID Connect** and enable **Standard flow**.

2. Configure:
   - **Valid redirect URIs:** `https://mcp-client.yourdomain.com/*`
   - **Valid post logout redirect URIs:** `https://mcp-client.yourdomain.com` (optional)
   - **Web origins:** `https://mcp-client.yourdomain.com`

   > **Local testing:** Add `http://localhost:*` as an additional valid redirect URI during development. Remove it before going live.

3. To define scopes, go to **Client scopes**, create each scope, then assign them to your client under the **Client scopes** tab.

### Define Scopes

Map your GraphQL authorization scopes to IdP scopes. This reference architecture uses:

| Scope | Purpose | Used By |
|-------|---------|---------|
| `user:read:email` | Read user email addresses | `@requiresScopes` on `User.email` |
| `inventory:read` | Read inventory levels | `@requiresScopes` on inventory fields |
| `order:read` | Read order data | Resolver-level checks |
| `cart:write` | Modify cart contents | Resolver-level checks |

These scopes must be defined in your IdP (see the provider-specific instructions above) and included in the token's `scope` claim. The Router's `@requiresScopes` directives and the MCP server's `scopes` configuration both reference these values.

### Configure the Audience

Set the audience (`aud` claim) to a value that identifies your MCP server. For example:

- `https://mcp.yourdomain.com`
- `apollo-mcp` (used in this reference architecture)

The same audience must be configured on both the MCP server and the Router.

| Provider | Where to Set Audience |
|----------|----------------------|
| Auth0 | **Applications > APIs** — the API **Identifier** becomes the `aud` claim |
| Okta | **Security > API > Authorization Servers** — add an **Audience** restriction |
| Keycloak | **Client Scopes** — configure an audience mapper on the client or use a hardcoded audience protocol mapper |

### Note the IdP URL

Record the base URL of your IdP. This is the issuer URL that appears in the OAuth/OIDC metadata document:

| Provider | IdP URL Format | Where to Find |
|----------|---------------|---------------|
| Auth0 | `https://your-tenant.auth0.com` | **Settings > General > Domain** |
| Okta | `https://your-org.okta.com/oauth2/default` | **Security > API > Authorization Servers > Issuer URI** |
| Keycloak | `https://keycloak.yourdomain.com/realms/your-realm` | Realm settings; the OIDC discovery endpoint is at `{issuer}/.well-known/openid-configuration` |

### Client Registration Approach

The [MCP authorization specification](https://modelcontextprotocol.io/specification/draft/basic/authorization#client-registration-approaches) defines three client registration mechanisms. Choose based on your scenario:

| Approach | When to Use | Spec Priority |
|----------|-------------|---------------|
| **Client ID Metadata Documents** | Client and server have no prior relationship (most common for MCP) | 1st (recommended) |
| **Pre-registration** | Client is known to the IdP ahead of time | 2nd |
| **Dynamic Client Registration (RFC 7591)** | Backwards compatibility or specific requirements | 3rd (fallback) |

**Client ID Metadata Documents** (CIMD) allow MCP clients to use an HTTPS URL as their `client_id`. The URL points to a JSON document describing the client (name, redirect URIs, grant types). The authorization server fetches and validates this document during the OAuth flow, eliminating the need for pre-registration or dynamic registration.

This reference architecture's built-in authorization server supports CIMD out of the box. It advertises `client_id_metadata_document_supported: true` in its [Authorization Server Metadata](https://datatracker.ietf.org/doc/html/rfc8414). When a URL-formatted `client_id` is presented during authorization, the server fetches the metadata document, validates the redirect URI against the document's `redirect_uris`, and displays the `client_name` on the consent screen.

Example metadata document hosted by an MCP client:

```json
{
  "client_id": "https://app.example.com/oauth/client-metadata.json",
  "client_name": "Example MCP Client",
  "client_uri": "https://app.example.com",
  "redirect_uris": [
    "http://127.0.0.1:3000/callback",
    "http://localhost:3000/callback"
  ],
  "grant_types": ["authorization_code"],
  "response_types": ["code"],
  "token_endpoint_auth_method": "none"
}
```

For production IdPs (Auth0, Okta, etc.), check whether your IdP supports CIMD natively. If not, pre-register your MCP clients in the IdP dashboard.

#### CIMD Auth Flow: Wire-Level Walkthrough

The following traces every HTTP exchange in the CIMD-based OAuth 2.1 flow. This is the exact sequence executed by this reference architecture's built-in authorization server (`subgraphs/users`).

##### Step 1 — Discover the authorization server

The MCP client fetches the Protected Resource Metadata to find the authorization server URL:

```http
GET /.well-known/oauth-protected-resource/mcp HTTP/1.1
Host: localhost:5001
```

```json
{
  "resource": "http://localhost:5001/mcp",
  "authorization_servers": ["http://localhost:4001"],
  "scopes_supported": ["user:read:email"],
  "bearer_methods_supported": ["header"]
}
```

The client then fetches Authorization Server Metadata from the discovered issuer:

```http
GET /.well-known/oauth-authorization-server HTTP/1.1
Host: localhost:4001
```

```json
{
  "issuer": "http://localhost:4001",
  "authorization_endpoint": "http://localhost:4001/authorize",
  "token_endpoint": "http://localhost:4001/token",
  "registration_endpoint": "http://localhost:4001/register",
  "jwks_uri": "http://localhost:4001/.well-known/jwks.json",
  "response_types_supported": ["code"],
  "grant_types_supported": ["authorization_code"],
  "code_challenge_methods_supported": ["S256"],
  "client_id_metadata_document_supported": true
}
```

`client_id_metadata_document_supported: true` tells the client it can use a URL as its `client_id` — no pre-registration needed.

---

##### Step 2 — Serve the Client ID Metadata Document

The MCP client hosts a JSON document at a URL it controls. In development this can be `http://localhost:9999/mcp-client`; in production it must be `https://`.

```http
GET /mcp-client HTTP/1.1
Host: localhost:9999
```

```json
{
  "client_id": "http://localhost:9999/mcp-client",
  "client_name": "Reference Architecture MCP Client",
  "client_uri": "http://localhost:9999",
  "redirect_uris": [
    "http://127.0.0.1:3000/callback",
    "http://localhost:3000/callback"
  ],
  "grant_types": ["authorization_code"],
  "response_types": ["code"],
  "token_endpoint_auth_method": "none"
}
```

The authorization server fetches this document on every `/authorize` and `/token` request. It validates that the `client_id` field in the document exactly matches the URL it was fetched from, then uses `redirect_uris` to validate the OAuth callback and `client_name` for the consent screen.

---

##### Step 3 — Generate PKCE parameters

The client generates a random `code_verifier` and derives `code_challenge = BASE64URL(SHA256(code_verifier))`:

```text
code_verifier  = "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk"
code_challenge = "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM"
method         = "S256"
```

---

##### Step 4 — Authorization request

```http
GET /authorize?response_type=code
  &client_id=http%3A%2F%2Flocalhost%3A9999%2Fmcp-client
  &redirect_uri=http%3A%2F%2Flocalhost%3A3000%2Fcallback
  &scope=user%3Aread%3Aemail
  &state=abc123
  &code_challenge=E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM
  &code_challenge_method=S256 HTTP/1.1
Host: localhost:4001
```

The server fetches the CIMD document from `http://localhost:9999/mcp-client`, verifies `redirect_uri` is in `redirect_uris`, and renders the login page with `client_name`:

```http
HTTP/1.1 200 OK
Content-Type: text/html

<!-- Login form: "Reference Architecture MCP Client is requesting access" -->
```

---

##### Step 5 — User submits credentials

```http
POST /authorize HTTP/1.1
Host: localhost:4001
Content-Type: application/x-www-form-urlencoded

username=user1&password=password123
  &client_id=http%3A%2F%2Flocalhost%3A9999%2Fmcp-client
  &redirect_uri=http%3A%2F%2Flocalhost%3A3000%2Fcallback
  &scope=user%3Aread%3Aemail
  &state=abc123
  &code_challenge=E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM
  &code_challenge_method=S256
```

The server re-fetches the CIMD document, validates credentials, stores the authorization code with the PKCE challenge, and redirects:

```http
HTTP/1.1 302 Found
Location: http://localhost:3000/callback?code=a1b2c3d4e5f6&state=abc123
```

---

##### Step 6 — Token exchange

```http
POST /token HTTP/1.1
Host: localhost:4001
Content-Type: application/x-www-form-urlencoded

grant_type=authorization_code
  &code=a1b2c3d4e5f6
  &redirect_uri=http%3A%2F%2Flocalhost%3A3000%2Fcallback
  &client_id=http%3A%2F%2Flocalhost%3A9999%2Fmcp-client
  &code_verifier=dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk
```

The server re-fetches the CIMD document, then verifies:
`BASE64URL(SHA256(code_verifier)) == stored_code_challenge`

On success, it issues a signed JWT:

```json
{
  "access_token": "eyJhbGciOiJFUzI1NiIsImtpZCI6Im1haW4ta2V5LTIwMjQifQ...",
  "token_type": "Bearer",
  "expires_in": 7200,
  "scope": "user:read:email"
}
```

---

##### Step 7 — Inspect the JWT

Header:

```json
{
  "alg": "ES256",
  "kid": "main-key-2024"
}
```

Payload:

```json
{
  "sub": "user:1",
  "scope": "user:read:email",
  "aud": "apollo-mcp",
  "iss": "http://localhost:4001",
  "iat": 1710000000,
  "exp": 1710007200
}
```

The `kid` references the signing key published at `/.well-known/jwks.json`. Both the MCP server and the Apollo Router use this endpoint to verify the signature independently.

---

##### Step 8 — Authenticated MCP request

```http
POST /mcp HTTP/1.1
Host: localhost:5001
Authorization: Bearer eyJhbGciOiJFUzI1NiIsImtpZCI6Im1haW4ta2V5LTIwMjQifQ...
Content-Type: application/json

{
  "jsonrpc": "2.0",
  "method": "tools/call",
  "params": {
    "name": "myProfileDetails",
    "arguments": {}
  },
  "id": 1
}
```

The MCP server validates the JWT signature and `scope`, then forwards the Bearer token to the Router. The Router re-validates the JWT independently and enforces `@requiresScopes` directives before resolving the query.

---

##### Implementation notes (built-in auth server)

- The CIMD document is fetched on **every** `/authorize` and `/token` request, not cached permanently (only `Cache-Control: max-age` is respected). This ensures revoked or updated redirect URIs take effect quickly.
- `isUrlClientId()` accepts `https://` URLs and `http://localhost` / `http://127.0.0.1` only. Cluster-internal HTTP URLs (e.g., `http://service.namespace.svc.cluster.local/...`) are rejected — this prevents an SSRF vector where an attacker controls an in-cluster HTTP service.
- Authorization codes expire after 5 minutes. The server stores them in memory (a `Map`), so **restarts or multiple replicas will invalidate outstanding codes**. Use a shared cache (Redis) or sticky sessions if this is a concern.

### Protected Resource Metadata (RFC 9728)

The Apollo MCP Server binary automatically serves [Protected Resource Metadata](https://datatracker.ietf.org/doc/html/rfc9728) using the `resource` field in `mcp.yaml`. No additional configuration is needed. When a client sends an unauthenticated request, the MCP server returns a `401` with a `WWW-Authenticate` header containing the `resource_metadata` URL, which clients use to discover the authorization server:

```http
HTTP/1.1 401 Unauthorized
WWW-Authenticate: Bearer resource_metadata="https://mcp.yourdomain.com/.well-known/oauth-protected-resource",
                         scope="user:read:email"
```

## Step 3: Configure the Apollo MCP Server

Replace the local dev auth configuration in `mcp.yaml`:

```yaml
endpoint: http://your-router-service:80

transport:
  type: streamable_http
  port: 8000
  host_validation:
    allowed_hosts:
      - "mcp.yourdomain.com"
  auth:
    servers:
      - https://your-idp.example.com
    audiences:
      - https://mcp.yourdomain.com
    allow_any_audience: false
    resource: https://mcp.yourdomain.com/mcp
    scopes:
      - user:read:email
    scope_mode: require_any

logging:
  level: info

introspection:
  introspect:
    enabled: true

operations:
  source: local
  paths:
    - /data/operations/myCart.graphql
    - /data/operations/myProfileDetails.graphql
```

Key differences from the local dev config:

- **`host_validation`**: Enabled with explicit allowed hosts instead of disabled
- **`auth.servers`**: Points to your external IdP instead of the users subgraph
- **`auth.audiences`**: Uses your production audience value
- **`auth.resource`**: Uses your production MCP URL
- **`logging.level`**: Set to `info` instead of `debug`

### Anonymous MCP Discovery

The local dev config enables `allow_anonymous_mcp_discovery`, which lets MCP clients call `initialize`, `tools/list`, and `resources/list` without a Bearer token. This lets users browse available tools before authenticating. All other MCP methods still require a valid OAuth token.

In production, consider whether exposing your tool catalog to unauthenticated callers is acceptable. If your tool names and descriptions are not sensitive, enabling this improves client compatibility (some agent frameworks need to discover tools before initiating OAuth). If tool metadata is confidential, leave it disabled (the default):

```yaml
transport:
  auth:
    allow_anonymous_mcp_discovery: false  # default; require auth for all methods
```

### Disabling Token Passthrough

By default, the MCP server forwards the client's OAuth token to the Router. If your Router uses a different authentication mechanism (e.g., API keys, a service-to-service token), you can disable passthrough:

```yaml
transport:
  auth:
    disable_auth_token_passthrough: true
```

### Per-Operation Scopes

For finer-grained access control, require specific scopes for specific operations:

```yaml
overrides:
  required_scopes:
    MyProfileDetails:
      - user:read:email
    MyCart:
      - cart:read
```

When a client calls a tool without the required scopes, the MCP server returns HTTP 403 with a `WWW-Authenticate` header indicating which scopes are needed. Clients can re-authorize with elevated scopes and retry.

## Step 4: Configure the Apollo Router

The Router must validate tokens from the same IdP. Update the `routerConfig` in your Supergraph CRD:

```yaml
routerConfig:
  authentication:
    router:
      jwt:
        jwks:
          - url: https://your-idp.example.com/.well-known/jwks.json
  authorization:
    directives:
      enabled: true
```

The Router:
1. Extracts the JWT from the `Authorization: Bearer <token>` header
2. Validates the signature using the IdP's JWKS endpoint
3. Extracts claims (`sub`, `scope`, `aud`) into the request context
4. Enforces `@authenticated` and `@requiresScopes` directives
5. Forwards the token and request to subgraphs

### Matching Audiences

If your IdP issues tokens with a specific audience, ensure the Router's JWT configuration accepts that audience. The Router validates the `aud` claim by default.

## Step 5: Deploy

### Update the Kubernetes Secret

Replace the credentials secret with production values:

```bash
kubectl create secret generic apollo-mcp-credentials \
  --namespace apollo \
  --from-literal=APOLLO_GRAPH_REF="your-graph-id@production" \
  --from-literal=APOLLO_KEY="your-apollo-key" \
  --from-literal=ROUTER_ENDPOINT="http://your-router-service:80" \
  --from-literal=MCP_RESOURCE_URL="https://mcp.yourdomain.com/mcp" \
  --dry-run=client -o yaml | kubectl apply -f -
```

Note that `AUTH_SERVER_URL` is no longer needed since the IdP URL is configured directly in `mcp.yaml`.

### Deploy via Helm

```bash
helm upgrade --install apollo-mcp-server \
  deploy/apollo-mcp-server \
  --namespace apollo \
  --wait
```

### Expose the MCP Server

In production, expose the MCP server via an Ingress or LoadBalancer with TLS termination:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: apollo-mcp-server
  namespace: apollo
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt
spec:
  tls:
    - hosts:
        - mcp.yourdomain.com
      secretName: mcp-tls
  rules:
    - host: mcp.yourdomain.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: apollo-mcp-server
                port:
                  number: 8000
```

## Security Considerations

### HTTPS Requirement

All production endpoints must use HTTPS:
- MCP server endpoint
- OAuth authorization server
- Token endpoint
- JWKS endpoint

### Token Passthrough Risks

The MCP server forwards client OAuth tokens to the Router by default. Be aware of:

- **Confused deputy attacks**: If the token's audience is too broad, it could be used to access services beyond the Router
- **Audience confusion**: Ensure the `aud` claim is specific to your API

Mitigations:
- Set `allow_any_audience: false` (default) and configure specific `audiences`
- Use a dedicated audience for your MCP server / GraphQL API
- Enable `disable_auth_token_passthrough` if the Router uses separate auth

### Token Lifetime

Configure short-lived access tokens (15–60 minutes) with refresh token rotation in your IdP. The demo uses 2-hour tokens for convenience, which is too long for production.

### Scope Least Privilege

Only request the scopes needed for the MCP tools being called. Use `scope_mode: require_any` with per-operation scopes for granular control rather than requiring all scopes on every request.

## Scope Strategy

### Mapping GraphQL Directives to OAuth Scopes

The scopes enforced by the MCP server should align with the authorization directives in your supergraph schema:

```graphql
# Schema directive → MCP scope
type User @authenticated {
  email: String @requiresScopes(scopes: [["user:read:email"]])
}

# MCP config
transport:
  auth:
    scopes:
      - user:read:email
    scope_mode: require_any
```

### Scope Hierarchies

For larger APIs, consider hierarchical scopes:

```yaml
overrides:
  required_scopes:
    MyProfileDetails:
      - user:read
    UpdateProfile:
      - user:write
    DeleteAccount:
      - user:write
      - admin
```

## Per-Operation Scope Requirements

The global `scopes` and `scope_mode` apply to every request. For step-up authorization, use `overrides.required_scopes`:

```yaml
transport:
  auth:
    scopes:
      - user:read:email
    scope_mode: require_any

overrides:
  required_scopes:
    SensitiveOperation:
      - admin
      - user:write
```

When a tool call is missing required scopes, the server returns:

```http
HTTP/1.1 403 Forbidden
WWW-Authenticate: Bearer error="insufficient_scope", scope="admin user:write"
```

Clients use this response to re-authorize with the needed scopes.

## Networking and DNS

### No `/etc/hosts` Workaround

In production, the MCP server, Router, and IdP all have real DNS names:

| Component | URL |
|-----------|-----|
| MCP Server (external) | `https://mcp.yourdomain.com/mcp` |
| Router (internal) | `http://router-service.apollo.svc.cluster.local:80` |
| Identity Provider | `https://your-idp.example.com` |

The MCP server runs inside the cluster and reaches the Router via in-cluster DNS. External clients reach the MCP server via its public URL. The IdP is accessible from both locations since it's an external service.

### Host Validation

Enable host validation in production to prevent DNS rebinding attacks:

```yaml
transport:
  host_validation:
    allowed_hosts:
      - "mcp.yourdomain.com"
```

## Troubleshooting

### Token Validation Failures

**Symptom:** `401 Unauthorized` on every MCP request after successful OAuth flow.

**Checks:**
1. Verify the MCP server can reach the IdP's JWKS endpoint from inside the cluster:
   ```bash
   kubectl exec -n apollo deployment/apollo-mcp-server -- \
     wget -qO- https://your-idp.example.com/.well-known/jwks.json
   ```
2. Verify the `aud` claim in the token matches `auth.audiences` in `mcp.yaml`
3. Check that the token hasn't expired

### Scope Mismatches

**Symptom:** `403 Forbidden` when calling MCP tools.

**Checks:**
1. Decode the JWT and inspect the `scope` claim (use [jwt.io](https://jwt.io))
2. Compare with the scopes configured in `mcp.yaml`
3. Check `scope_mode` — `require_all` (default) is stricter than `require_any`

### Discovery Failures

**Symptom:** MCP client can't find the authorization server.

**Checks:**
1. Verify the IdP serves metadata at one of:
   - `/.well-known/oauth-authorization-server`
   - `/.well-known/openid-configuration`
2. If the IdP is slow, increase `discovery_timeout`:
   ```yaml
   transport:
     auth:
       discovery_timeout: 10s
   ```

### Router Rejects Forwarded Tokens

**Symptom:** MCP tools return GraphQL errors with `UNAUTHENTICATED` or fields return `null`.

**Checks:**
1. Ensure the Router's JWKS URL points to the same IdP as the MCP server
2. Verify the Router accepts the token's audience
3. Check that header propagation is configured:
   ```yaml
   routerConfig:
     headers:
       all:
         request:
           - propagate:
               matching: ".*"
   ```
