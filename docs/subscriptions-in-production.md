# Subscriptions in production

> Choosing a transport, sizing the runtime, observability, and the operational pitfalls that surface only at scale. Tracks [AS-302](https://apollographql.atlassian.net/browse/AS-302).

> [!NOTE]
> Synthesized from public Apollo guidance and field patterns. The source Google Doc cited on the original ticket should be folded in before this is migrated upstream to the public docs site.

## Pick the transport before you pick the runtime

Apollo Router supports two subscription transports. The choice has more impact on your infrastructure than any other knob:

| Transport | When to use | Cost |
| --- | --- | --- |
| **WebSocket (`graphql-ws`)** | Real-time UX needs bidirectional, sub-second updates (live trades, presence, collaborative editing). | Router and subgraphs both hold long-lived connections. Memory scales linearly with concurrent subscribers. Doesn't survive scale-to-zero. |
| **HTTP Callback** | Eventing for backend systems, infrequent updates, or anywhere the platform doesn't tolerate persistent connections (Cloud Run, App Runner). | Polling cost on the subscriber side; Router holds no connection state. |

Default to **callback mode** unless you have a confirmed product requirement for true real-time. Most enterprise "real-time" requirements turn out to need only second-granularity updates, which polling delivers more cheaply.

## Sizing Router for WebSocket subscriptions

Every active subscription costs the Router:

- ~8–16 KB of heap (the WS frame buffer + the per-stream state machine).
- One file descriptor.
- One distinct open subscription tracked by `apollo_router_opened_subscriptions` (OTel: `apollo.router.opened.subscriptions`). After deduplication the same metric reflects the count of distinct upstream subscriptions, not the count of connected clients.

A 4 vCPU / 8 GiB Router holds 50k–100k idle subscriptions comfortably, but only ~5k subscriptions that all receive an event every second. The bottleneck shifts from memory to CPU as event frequency rises.

Plan capacity with the rate of `apollo_router_opened_subscriptions` (distinct active subscriptions) and `apollo_router_skipped_event_count_total` (events dropped under backpressure) as the primary inputs. Per-instance:

```
target_cpu_pct =
  base_cpu_at_idle
  + (events_per_second × avg_active_subscribers_per_event × 1.2µs)
```

The 1.2 µs constant is heuristic from internal benchmarks; verify against your shape before scaling decisions.

## Subgraph subscription source

The subgraph delivers events to Router via:

- **`graphql-ws`** (WebSocket) — most subgraph frameworks support this natively. The Router maintains one upstream WS per subscription.
- **HTTP callback** — the subgraph POSTs events to a Router-exposed URL. Useful when the subgraph runs on Lambda / serverless where long-lived connections aren't practical.

Match the subgraph transport to the subgraph runtime, not to the client transport. The Router can translate between them — clients can use callback while subgraphs use WS, or vice versa.

## Authentication & authorization for long-lived connections

JWTs expire. WebSocket connections don't. Two patterns:

1. **Re-auth on each event** — Router validates the JWT in the connection init payload, then re-validates per event. Highest cost; survives JWT expiry.
2. **Hard close on expiry** — Router validates once at connection time and closes the connection when the JWT `exp` lapses. Clients reconnect with a fresh token. Cheapest; users see a UI blip on every token refresh.

Pick (2) for B2C with short token TTLs; pick (1) for B2B with long-lived service-account tokens.

## Backpressure

Subgraphs can produce events faster than clients can consume them. Router applies backpressure by:

- Dropping events when the per-client buffer is full (counted as `apollo_router_skipped_event_count_total`; OTel: `apollo.router.skipped.event.count`).
- Coalescing duplicate subgraph connections: when N clients subscribe to the same operation, the Router opens one upstream subscription and fans out events to all N. `apollo_router_opened_subscriptions` reflects the post-dedup count, not the client count — so a flat gauge with growing connection counts is healthy.

Watch `apollo_router_skipped_event_count_total` — bounded is healthy, growing unbounded is the canary for client buffers overflowing. See [`router-grafana-template`](https://github.com/apollosolutions/router-grafana-template) for the dashboard wiring (AS-342).

## Operational pitfalls

- **Load balancers cap connection lifetime.** AWS NLB defaults to 350 s idle; ALB defaults to 60 s. Set the limit at least 10× longer than your typical subscription, or expect clients to reconnect on every load-balancer-imposed close.
- **Sticky sessions are not needed for `graphql-ws`** at the LB layer — the WebSocket handshake itself pins the connection to one Router pod for its lifetime. Sticky sessions _are_ needed for callback subscriptions if the same client is to receive events from a deterministic Router.
- **Rolling deploys disconnect everyone.** When Router pods roll, every WS connection terminates. Schedule deploys outside peak hours, or pre-drain via lifecycle hooks. Callback subscriptions survive rolling deploys.
- **Subscription queries that fan out to many subgraphs amplify cost.** A subscription with five `@key` joins fetches all five subgraphs on every event. Audit subscription operations for join depth before promoting them to production.

## See also

- [Router subscriptions configuration](https://www.apollographql.com/docs/graphos/routing/operations/subscriptions)
- [TN0047: HTTP subscriptions through an API gateway](https://www.apollographql.com/docs/technotes/TN0047-using-http-subscriptions-api-gateway/)
- [`router-grafana-template`](https://github.com/apollosolutions/router-grafana-template) — observability dashboard with subscription row (AS-342)
- [`apollosolutions/subscriptions-best-practices-examples`](https://github.com/apollosolutions/subscriptions-best-practices-examples)
