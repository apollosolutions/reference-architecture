# Persisted Queries vs. Automatic Persisted Queries

> The two are not the same feature and the trade-offs are usually misunderstood. Tracks [AS-315](https://apollographql.atlassian.net/browse/AS-315).

| | **Persisted Queries (PQs)** | **Automatic Persisted Queries (APQs)** |
| --- | --- | --- |
| **Who decides what's allowed** | Server / publishing pipeline | Anyone who can send a query the first time |
| **Trust model** | Allowlist (default-deny) | Cache (any well-formed query allowed) |
| **First hit** | Client sends operation `id`, no body | Client sends `id`; on miss, retries with body |
| **Network savings** | Always — body is never sent | Only after first hit warms the cache |
| **Security posture** | Strong — blocks introspection, blocks ad-hoc queries | Weak — does nothing to prevent malicious queries |
| **Where the operation lives** | Manifest in GraphOS / Router | Anywhere the client decides to send it |

If you only remember one thing: **PQs are an allowlist. APQs are a cache.** Mixing them up at design time leaves teams with neither security nor network savings.

## When to choose Persisted Queries

- You control your clients (first-party web/mobile/desktop).
- You want to disable arbitrary queries in production (default-deny).
- Compliance requires that you log _which_ operation hit your graph, not just that _some_ operation did.
- You're targeting clients on slow networks where shipping the operation body adds tens of ms per request.

PQs scale linearly with the operations you ship per release. Build a CI step that:
1. Extracts operations from the client codebase at build time.
2. Pushes them to a [PQ manifest](https://www.apollographql.com/docs/graphos/operations/persisted-queries) under a client name + version.
3. Configures the Router to require PQs and enforce per-client-version allowlists.

Audit-mode posture (collect unmatched ids without rejecting them):

```yaml title="router.yaml — PQ audit mode (don't enforce yet)"
persisted_queries:
  enabled: true
  log_unknown: true   # log operations that don't match the manifest
  # safelist is intentionally omitted here — enabling it rejects unknowns.
```

Once the unknown rate hits zero in production, flip on enforcement:

```yaml title="router.yaml — PQ enforcement"
persisted_queries:
  enabled: true
  safelist:
    enabled: true
    require_id: true  # reject operations that don't carry an id
```

## When to choose Automatic Persisted Queries

- You can't control all your clients (public API, partner-built clients).
- Your only goal is bandwidth — shaving 5–20 KB off the request body on subsequent hits.
- You accept that any query a client sends once becomes cacheable forever (until eviction).

APQs are essentially free to enable on the Router side. They add about a dozen lines of client logic (Apollo Client supports them via `createPersistedQueryLink({ useGETForHashedQueries: true })`).

```yaml title="router.yaml — APQ"
apq:
  enabled: true
  router:
    cache:
      in_memory:
        limit: 1000 # tune by your operation diversity
```

## Combining them — the recommended pattern for first-party clients

You don't have to pick. The pattern that gives both security and bandwidth savings:

1. **Persisted Queries** enforced at the Router, populated from your CI build of first-party clients.
2. **APQs** enabled _for first-party clients only_ — adds the bandwidth saving on top.
3. Anyone else hitting the graph (third-party, ad-hoc, browser tools) has to send the full body and is subject to operation limits.

The Router can apply different rules per client name (set via `apollographql-client-name` header), so first-party traffic gets the allowlist while monitoring/ad-hoc traffic falls through to the standard enforcement.

## Migration order matters

If you're moving from no enforcement to PQs:

1. Enable `log_unknown` for at least one full release of the slowest-moving client (often mobile). Don't enforce yet.
2. Inspect logs for operations that should be in the manifest but aren't (often from staging tools or scheduled jobs).
3. Add missing operations or explicitly exclude that client name from the allowlist.
4. Flip `safelist.enabled: true` only after the unknown rate hits zero in production.

Most production outages from PQ rollouts come from skipping step 1.

## See also

- [Apollo Persisted Queries](https://www.apollographql.com/docs/graphos/operations/persisted-queries)
- [Automatic Persisted Queries](https://www.apollographql.com/docs/graphos/routing/operations/apq)
- [TN0024 Schema Deprecations](https://www.apollographql.com/docs/technotes/TN0024-deprecations/) — PQ manifests are also the cleanest way to know whether deprecating a field is safe.
- [Apollo Client PQ link](https://www.apollographql.com/docs/react/api/link/persisted-queries/)
