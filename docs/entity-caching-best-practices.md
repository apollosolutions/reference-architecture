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
preview_entity_cache:
  enabled: true
  redis:
    urls:
      - redis://redis-master.redis.svc.cluster.local:6379
    timeout: 5ms # fast-fail on Redis hiccups; better to serve stale-from-origin than to hang
  subgraph:
    all:
      enabled: true
      ttl: 5m
    subgraphs:
      products:
        enabled: true
        ttl: 1h # products rarely change, longer TTL is safe
      inventory:
        # Inventory is read-heavy but stale data is dangerous; keep TTL short
        # or disable entirely if eventual consistency is unacceptable.
        enabled: true
        ttl: 30s
```

The TTL is per-subgraph, not per-type. Within one subgraph you can scope tighter with `@cacheControl(maxAge: ...)` on individual types and fields in the subgraph SDL — the Router takes the minimum of the per-subgraph TTL and the directive.

## Cache key composition

The Router keys entries on:

1. The entity key (the value of fields named in `@key`).
2. The set of fields being selected — different selection sets bucket separately.
3. Request-context variables you've explicitly added to the cache key (see "Per-tenant caching" below).

What's _not_ in the key by default: the JWT, the client name, the originating IP, anything in `extensions`. If your authorization decisions depend on the viewer, you _must_ add the viewer claim to the cache key, otherwise users will see other users' cached responses.

## Per-tenant / per-locale caching

```yaml title="router.yaml — extending the cache key"
preview_entity_cache:
  subgraph:
    subgraphs:
      products:
        invalidation:
          private: true
        # The cache key is composed of the JWT 'tenant' claim and an
        # Accept-Language header. Two different tenants get two different
        # cache buckets for the same product id.
        cache_key_modifiers:
          - context: $.jwt_claims.tenant
          - header: accept-language
```

Rule of thumb: every dimension that changes the response must be in the key. The fastest way to verify is to fetch the same entity twice with different viewers/locales and dump the cache key from the Router debug log.

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

- [Apollo Router entity caching docs](https://www.apollographql.com/docs/router/configuration/entity-caching/)
- [`@cacheControl` directive](https://www.apollographql.com/docs/router/configuration/entity-caching/#cachecontrol-directive)
- [Response caching guide](./response-caching-guide.md) — the sibling response-cache feature, scoped to entire operations rather than entities.
- [TN0011 Response Cache Eviction](https://www.apollographql.com/docs/technotes/TN0011-response-cache-eviction/) — covers the older response cache; many invalidation lessons apply to entity caching too.
