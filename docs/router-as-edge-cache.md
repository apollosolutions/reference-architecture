# Apollo Router as an edge cache

> The Router can stand in as a GraphQL-aware edge cache layer in front of subgraphs. When it's the right call, and how to wire it up with Redis. Tracks [AS-335](https://apollographql.atlassian.net/browse/AS-335).

A CDN edge cache works at the HTTP-request layer — same URL + same headers → cache hit. That model doesn't fit GraphQL, where two requests with very different selection sets share `POST /graphql` and a JSON body. The Router fills the gap by caching at the **operation** and **entity** layer instead.

## Two layers, two purposes

| Layer | What's cached | Default TTL | When to use |
| --- | --- | --- | --- |
| **Response cache** | Full operation responses, keyed by `(query hash, variables, headers in key)` | Short (seconds) | Hot operations that return identical responses across many users (anonymous pricing pages, public catalog reads). |
| **Entity cache** | Individual `@key`-identified entities, keyed by `(entity key, fields, optional viewer)` | Medium (minutes to hours) | High read-to-write ratio on identifiable entities (products, articles, accounts). |

Most production deployments enable both. The response cache absorbs hot identical requests; the entity cache covers the long tail.

## Topology

```
        ┌────────────┐
client ─► Apollo      ◄── Redis (response cache + entity cache)
        │ Router     │
        │            ◄── subgraphs (cache miss path)
        └────────────┘
```

Redis is the standard backing store for both layers. The Router talks to it over plain TCP (or TLS); deploy Redis in the same VPC as the Router for lowest latency. A 6 GB Redis instance comfortably backs a multi-Router cluster up to ~10k qps.

## Configuration

Current Router (v2.6+) configures both whole-operation and entity-representation caching under a single `response_cache` block — there is no separate `preview_response_cache` or `preview_entity_cache`. TTL belongs under `subgraph.all.ttl` (required to start), and Redis settings live under `subgraph.all.redis`:

```yaml title="router.yaml"
response_cache:
  enabled: true
  subgraph:
    all:
      enabled: true
      ttl: 30s        # fallback TTL when no `Cache-Control` from subgraph; required
      redis:
        urls:
          - redis://redis-master.redis.svc.cluster.local:6379
        # Realistic Redis round-trip budget. Too aggressive a value (e.g.
        # 5 ms) fails most lookups and defeats the cache; tune to your VPC.
        timeout: 200ms
    subgraphs:
      products:
        ttl: 1h       # static-ish content, longer TTL safe
      inventory:
        ttl: 30s      # changes frequently; keep short

telemetry:
  instrumentation:
    instruments:
      router:
        # Surface the cache decision in your metrics so dashboards can
        # show hit rate by operation.
        http.server.request.duration:
          attributes:
            apollo.router.response.cache.hit:
              on_response: true
              from_response_extensions: cache_hit
```

Subgraph-level TTL overrides ride under `response_cache.subgraph.subgraphs.<name>.ttl`. Entity-representation caching is part of the unified `response_cache` config — there is no second cache block to maintain.

A Redis timeout strikes the user-facing path with **fall-through to origin**, not a stall. The Router still issues lookups when Redis is down; what changes is the failure mode (fast fall-back vs. cache hit).

## Cache key composition — the critical rule

By default the cache key includes the operation hash + variables. It **does not** include:
- Inbound JWT or claims
- `apollographql-client-name` / `apollographql-client-version`
- Custom headers
- The viewer

If any of those affect what the response should be, you must add them to the key. The most common production incident: a `Query.cart` cached for one user is returned to a different user because viewer identity wasn't in the key. See [`entity-caching-best-practices.md`](./entity-caching-best-practices.md) for the per-tenant / per-viewer pattern.

## Where Router cache is the wrong answer

- **Mutations.** Don't cache `Mutation.*`. The Router doesn't by default; just don't disable that.
- **Authenticated personalised reads** without putting viewer identity in the key. Either add to the key, or scope caching to anonymous traffic only.
- **Real-time data.** A 30-second cached price is wrong for trading apps even if it's right for a marketing page.
- **In place of a CDN for media.** Image and bundle delivery still belong on a CDN. Router caching is for GraphQL responses.

## When edge cache + Router both make sense

Run a CDN for everything that isn't `POST /graphql` and let the Router cache the GraphQL traffic. The two don't conflict — the CDN handles the static surface (HTML, JS, CSS, images) and Router handles the API surface.

For very hot anonymous public queries (a homepage's product list shared across all visitors), the Router response cache _is_ the edge cache. Latency to a Redis hit is single-digit milliseconds — competitive with a true CDN edge response.

## Operational pitfalls

- **Stale data after subgraph deploys.** Subgraphs that change their resolver behaviour (not their schema) won't trigger Router cache invalidation. Either bump a `cache_key_modifier` you control, or wait out the TTL.
- **Redis memory pressure.** Always set `maxmemory-policy allkeys-lru` and `maxmemory` to ~70% of the Redis instance memory. Without LRU eviction, the keyspace can fill and stall.
- **Per-subgraph TTL drift.** The TTL on a `Product` cached in subgraph A is independent of any cache on `Product` in subgraph B. Cross-subgraph reads can serve mixed-freshness data — usually fine, but worth knowing.

## See also

- [Response caching guide](./response-caching-guide.md) — the existing in-repo walkthrough this builds on
- [Entity caching best practices](./entity-caching-best-practices.md) (AS-240)
- [Router entity caching docs](https://www.apollographql.com/docs/router/configuration/entity-caching/)
- [TN0011 Response Cache Eviction](https://www.apollographql.com/docs/technotes/TN0011-response-cache-eviction/)
