# MCP Auth Verification

Verification checklist for the MCP server OAuth configuration. Run these checks after deploying the MCP server (script 12) and starting port-forwards (script 12a).

**Prerequisites:**
- Port-forwards active: MCP at `localhost:5001`, auth server at `localhost:4001`
- `/etc/hosts` entry for `graphql.users.svc.cluster.local` pointing to `127.0.0.1`

## 1. Connectivity

```bash
# MCP server should return 401 (auth required)
curl -s -o /dev/null -w "%{http_code}" http://localhost:5001/mcp
# Expected: 401

# Auth server metadata should return 200
curl -s -o /dev/null -w "%{http_code}" http://localhost:4001/.well-known/oauth-authorization-server
# Expected: 200
```

## 2. Authorization Server Metadata (RFC 8414)

```bash
curl -s http://localhost:4001/.well-known/oauth-authorization-server | jq .
```

Verify the response contains:
- `issuer` — matches the auth server URL
- `token_endpoint` — ends with `/token`
- `authorization_endpoint` — ends with `/authorize`
- `jwks_uri` — ends with `/.well-known/jwks.json`
- `code_challenge_methods_supported` — includes `"S256"`
- `registration_endpoint` — ends with `/register` (RFC 7591 fallback)
- `scopes_supported` — includes `"user:read:email"` and others
- `client_id_metadata_document_supported` — is `true`

## 3. JWKS Endpoint

```bash
curl -s http://localhost:4001/.well-known/jwks.json | jq '.keys[0].kid'
# Expected: "main-key-2024"
```

## 4. Dynamic Client Registration (RFC 7591 fallback)

```bash
curl -s -X POST http://localhost:4001/register \
  -H "Content-Type: application/json" \
  -d '{"redirect_uris":["http://localhost:9999/callback"]}' | jq .
```

Verify the response contains `client_id` and `client_secret`.

## 5. Client ID Metadata Document Path

```bash
# URL-formatted client_id should trigger CIMD fetch (fails with 400 for unreachable URL)
curl -s -o /dev/null -w "%{http_code}" \
  "http://localhost:4001/authorize?client_id=https://example.com/nonexistent.json&redirect_uri=http://localhost:9999/callback&state=test&scope=user:read:email&code_challenge=test&code_challenge_method=S256"
# Expected: 400 (CIMD fetch failed)

# Non-URL client_id should render login page normally
curl -s -o /dev/null -w "%{http_code}" \
  "http://localhost:4001/authorize?client_id=client_test123&redirect_uri=http://localhost:9999/callback&state=test&scope=user:read:email&code_challenge=test&code_challenge_method=S256"
# Expected: 200 (login page)
```

## 6. Anonymous MCP Discovery

```bash
# initialize without auth should succeed
curl -s -X POST http://localhost:5001/mcp \
  -H "Content-Type: application/json" \
  -H "Accept: application/json, text/event-stream" \
  -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"verify","version":"1.0"}}}'
# Expected: response containing "serverInfo"

# tools/list without auth should succeed
curl -s -X POST http://localhost:5001/mcp \
  -H "Content-Type: application/json" \
  -H "Accept: application/json, text/event-stream" \
  -d '{"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}}'
# Expected: response containing "tools" array
```

## 7. WWW-Authenticate Header (RFC 9728)

```bash
curl -s -D - -o /dev/null -X POST http://localhost:5001/mcp \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"MyProfileDetails","arguments":{}}}' 2>&1 | grep -i "www-authenticate"
# Expected: WWW-Authenticate header containing "resource_metadata"
```

## 8. Full OAuth Token Flow

```bash
# Step 1: Register a client
CLIENT_ID=$(curl -s -X POST http://localhost:4001/register \
  -H "Content-Type: application/json" \
  -d '{"redirect_uris":["http://localhost:19876/callback"]}' | jq -r '.client_id')

# Step 2: Submit login and capture auth code from redirect
AUTH_CODE=$(curl -s -D - -o /dev/null -X POST http://localhost:4001/authorize \
  -d "username=user1&password=test&client_id=$CLIENT_ID&redirect_uri=http://localhost:19876/callback&state=test&scope=user:read:email&code_challenge=E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM&code_challenge_method=S256" \
  2>/dev/null | grep -i "location:" | grep -o 'code=[^&]*' | cut -d= -f2 | tr -d '\r')
echo "Auth code: $AUTH_CODE"

# Step 3: Exchange code for token
TOKEN_RESP=$(curl -s -X POST http://localhost:4001/token \
  -d "grant_type=authorization_code&code=$AUTH_CODE&redirect_uri=http://localhost:19876/callback&client_id=$CLIENT_ID")
echo "$TOKEN_RESP" | jq .

# Step 4: Verify JWT claims
ACCESS_TOKEN=$(echo "$TOKEN_RESP" | jq -r '.access_token')
echo "$ACCESS_TOKEN" | cut -d. -f2 | base64 -d 2>/dev/null | jq .
# Expected: aud="apollo-mcp", sub="user:1", scope="user:read:email"
```

## Summary of Expected Results

| Check | Expected |
|-------|----------|
| MCP server connectivity | HTTP 401 |
| Auth server metadata | HTTP 200 with all required fields |
| `client_id_metadata_document_supported` | `true` |
| `scopes_supported` | `["user:read:email", "inventory:read", "order:read", "cart:write"]` |
| JWKS kid | `main-key-2024` |
| Dynamic registration | Returns `client_id` |
| URL client_id at /authorize | HTTP 400 (CIMD fetch fails for fake URL) |
| Non-URL client_id at /authorize | HTTP 200 (login page) |
| Anonymous initialize | Succeeds with `serverInfo` |
| Anonymous tools/list | Succeeds with `tools` array |
| WWW-Authenticate on 401 | Contains `resource_metadata` |
| Token flow | JWT with `aud=apollo-mcp`, `sub=user:1` |
