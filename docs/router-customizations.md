# Router customizations: Rhai vs Coprocessors

> When to use each, and what doesn't fit either. Tracks [AS-319](https://apollographql.atlassian.net/browse/AS-319).

The Router has two extension surfaces. They overlap in capability but diverge in cost, deployability, and latency. Picking the wrong one is the most common operational regret on long-lived Router deployments.

## The decision in one table

| | **Rhai script** | **Coprocessor** |
| --- | --- | --- |
| **Language** | Rhai (Rust-flavored embedded DSL) | Any HTTP server: Go, JS, Python, Java, .NET, … |
| **Where it runs** | In-process inside Router | Separate service over HTTP |
| **Latency added per hook** | ~10–100 µs | 1–10 ms (network + serialization) |
| **External I/O** | Limited (built-in `fetch` only, blocking) | Anything the runtime can do (DB, cache, IDP, gRPC) |
| **Failure mode** | Crash inside Router → 500 on the operation | Coprocessor down → configurable (fail-open or fail-closed per stage) |
| **Deployability** | One YAML pointer + a `.rhai` file | A separate service to deploy, scale, and observe |
| **Hot reload** | Yes (Router watches the file) | No (coprocessor binary redeploys) |
| **Test story** | `rhai-test` framework (from `apollosolutions/rhai-test`) | Standard HTTP service testing |

Rule of thumb: **stay in Rhai** until you need (a) a real DB / cache / IDP call, (b) a language your team already maintains, or (c) more than ~200 lines of logic. Cross either bar and the coprocessor's operational overhead pays for itself.

## What Rhai is good at

Header transformations, claim-based routing, simple request/response decorations, structured logging. The hot path stays in-process so the latency cost is negligible.

```rhai
// router.rhai — strip a sensitive internal header before subgraph fetch
fn subgraph_service(service, subgraph){
    service.map_request(|request|{
        request.subgraph.headers.remove("x-internal-only");
        if request.subgraph.headers.contains("authorization") {
            request.subgraph.headers.set("x-request-from-router", "true");
        }
    });
}
```

When the rule changes you redeploy the file (or rely on file-watch hot reload). Customers love this for the iteration speed.

## What coprocessors are good at

- **Auth flows that need IdP I/O** — token introspection, refresh-grant exchange, claim enrichment from a directory.
- **Custom rate-limiting** that consults Redis or a downstream rate-limit service.
- **Audit logging** that ships structured events to Kafka / a SIEM with delivery guarantees.
- **Multi-step transformation logic** that's easier to write and test in your team's primary language.

```javascript
// coprocessor.js — claim enrichment from an internal directory
import { ApolloRouterCoprocessor } from "@apollo/router-coprocessor";

new ApolloRouterCoprocessor()
  .onSupergraphRequest(async (req) => {
    const user = await directory.lookupBySub(req.context.entries.jwt_claims.sub);
    req.context.entries.user_groups = user.groups;
    return req;
  })
  .listen(4001);
```

The coprocessor is deployed alongside Router (often as a sidecar in Kubernetes, or as an adjacent ECS service). The `reference-architecture` repo's `coprocessor/` directory is the canonical example layout.

## Failure modes worth deciding upfront

For coprocessors, every stage (RouterService, SupergraphService, ExecutionService, SubgraphService) can be configured **fail-open** (proceed on coprocessor error) or **fail-closed** (return 500). The defaults are fail-open. Default to **fail-closed for auth/authz** stages, **fail-open for logging/telemetry** stages — getting these reversed leads to either silent auth bypass or every subgraph failure cascading from coprocessor hiccups.

For Rhai, there's no fail-open option: an unhandled error inside the script becomes a 500 response. Defensive coding (`try`/`catch`) matters.

## See also

- [Router Rhai docs](https://www.apollographql.com/docs/router/customizations/rhai)
- [Router coprocessor docs](https://www.apollographql.com/docs/router/customizations/coprocessor)
- [`apollosolutions/rhai-test`](https://github.com/apollosolutions/rhai-test) — unit-test framework for Rhai scripts
- [`apollosolutions/coprocessor-examples`](https://github.com/apollosolutions/coprocessor-examples) — coprocessor starters across languages
- [`coprocessor/`](../coprocessor/) — the working coprocessor used by this reference architecture
