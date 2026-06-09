# Entity caching best practices

> Patterns, configuration, and pitfalls for the Router's entity-level response cache. Tracks [AS-240](https://apollographql.atlassian.net/browse/AS-240).

> [!NOTE]
> First-draft synthesis of public Apollo guidance plus general patterns observed across customer engagements. Wayfair-specific learnings — the original ticket's source material — should be folded in by a reviewer with access to those notes before this is migrated to the public docs site.

## When entity caching pays off

Entity caching shines when:

- **Read shape repeats**. The same `Product`, `User`, or `Inventory` entity is fetched by name across many operations. Caching one entity once benefits N operation patterns.
- **Subgraphs are expensive**. Backing services are slow (50 ms+ p50), rate-limited, or paid-per-call.
- **Authorization is per-field, not per-row**. The cache key needs to capture _what's_ being returned; if every user sees a different row in the same entity, you cache misses constantly.

It is a poor fit when:

- The data changes faster than the smallest useful TTL (sub-second).
- Personalisation lives _inside_ the entity (per-viewer pricing, per-tenant pricing without tenant key in the cache key).
- The subgraph response includes server-rendered HTML or signed URLs with embedded timestamps — the response itself is unique per request.

## Configuration shape

```yaml title="router.yaml — entity caching at the subgraph level"
response_cache:
  enabled: true
  subgraph:
    all:
      enabled: true
      ttl: 5m            # required when response caching is enabled
      redis:
        urls:
          - redis://redis-master.redis.svc.cluster.local:6379
        # Realistic Redis round-trip budget — too aggressive a value will fail
        # most lookups and fall back to origin, defeating the cache.
        timeout: 200ms
    subgraphs:
      products:
        enabled: true
        ttl: 1h          # products rarely change, longer TTL is safe
      inventory:
        # Inventory is read-heavy but stale data is dangerous; keep TTL short
        # or disable entirely if eventual consistency is unacceptable.
        enabled: true
        ttl: 30s
```

The TTL is per-subgraph, not per-type. Subgraphs that emit `Cache-Control` headers can override the fallback TTL per response — the Router takes the value the subgraph returned when present, otherwise the configured `subgraph.<name>.ttl`.

## Cache key composition

The Router keys entries on:

1. The entity key (the value of fields named in `@key`).
2. The set of fields being selected — different selection sets bucket separately.
3. Request-context variables you've explicitly added to the cache key (see "Per-tenant caching" below).

What's _not_ in the key by default: the JWT, the client name, the originating IP, anything in `extensions`. If your authorization decisions depend on the viewer, you _must_ add the viewer claim to the cache key, otherwise users will see other users' cached responses.

## Per-user / per-tenant caching

For per-user caching, point `private_id` at a context field (typically the JWT `sub` or a tenant claim) — the Router segments cache entries by that value so two viewers don't see each other's data:

```yaml title="router.yaml — segment cache per user/tenant"
response_cache:
  subgraph:
    subgraphs:
      products:
        # Point private_id at a flat context key you populate from the JWT sub
        # claim via a Rhai supergraph_service hook. Using a nested dotted path
        # directly (e.g. apollo::authentication::jwt_claims.sub) is not reliably
        # resolved; populate an intermediate key first:
        #   request.context["user:sub"] = claims?.sub ?? ""  (in Rhai)
        private_id: "user:sub"
```

For dimensions that aren't a simple context field — for example combining a tenant claim with `Accept-Language` — set the cache key explicitly at runtime by writing the `apollo::response_cache::key` context entry from a Rhai script or coprocessor before the subgraph fetch:

```rhai title="router.rhai — extend the cache key from request context"
fn subgraph_service(service, _subgraph) {
    service.map_request(|request| {
        let tenant = request.context["apollo::authentication::jwt_claims"]?.tenant ?? "anon";
        let locale = request.subgraph.headers["accept-language"] ?? "*";
        // The cache key entry takes a JSON object keyed by scope ("all",
        // "subgraphs.<name>", or an operation name). A bare string is ignored.
        request.context["apollo::response_cache::key"] = #{
            "all": `tenant=${tenant};lang=${locale}`
        };
    });
}
```

Rule of thumb: every dimension that changes the response must be in the key. The fastest way to verify is to fetch the same entity twice with different viewers/locales and confirm the keys differ in the Router debug log.

## Invalidation

The Router doesn't push invalidations from subgraphs — TTL is the primary expiry mechanism. Two patterns we use to side-step this:

1. **Short TTL + write-through** — keep TTL ~60 s and let writes flow naturally. Acceptable when the entity is read 100×–1000× per write.
2. **Out-of-band Redis `DEL`** — subgraph writes publish a key to Redis after committing, and a small worker deletes the matching Router cache entries. Works but bypasses the Router; cache keys must be deterministic and documented across services.

## Operational pitfalls

- **Memory blow-up in Redis**. Set `maxmemory-policy allkeys-lru` on the Redis backing the cache. Without it, large schemas can fill the keyspace and stall writes.
- **Cold-cache thundering herd**. After a Redis restart, every entity fetch goes to origin simultaneously. Mitigate with a small singleflight in front of the subgraph, or staggered TTL jitter.
- **Sub-microsecond cache hits look like origin hits in traces**. The Router emits a `cache.hit=true` attribute on the subgraph span; filter your dashboards on that, not on subgraph latency alone.
- **Distributed cache vs. in-process cache**. The in-process query plan cache is unrelated to the entity cache — don't conflate them in your operational runbook.

## Verifying

Use Apollo Sandbox + the Router debug logs:

```bash
# Show cache hit/miss decisions
RUST_LOG="apollo_router::services::entity_cache=debug" router
```

Each request emits a line per subgraph fetch with the cache key, the decision (hit/miss/refresh), and the source TTL.

## See also

- [Apollo Router entity caching docs](https://www.apollographql.com/docs/graphos/routing/performance/caching/entity)
- [Subgraph `Cache-Control` header behaviour](https://www.apollographql.com/docs/graphos/routing/performance/caching/entity#cache-control-header)
- [Response caching guide](./response-caching-guide.md) — the sibling response-cache feature, scoped to entire operations rather than entities.
- [TN0011 Response Cache Eviction](https://www.apollographql.com/docs/technotes/TN0011-response-cache-eviction/) — covers the older response cache; many invalidation lessons apply to entity caching too.
