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
| **Failure mode** | Unhandled error inside Router → 500 on the operation | Coprocessor unreachable/non-2xx/timeout → 500 on the operation (fail-closed; no per-stage toggle) |
| **Deployability** | One YAML pointer + a `.rhai` file | A separate service to deploy, scale, and observe |
| **Hot reload** | Yes (Router watches the file) | No (coprocessor binary redeploys) |
| **Test story** | `rhai-test` framework (from `apollosolutions/rhai-test`) | Standard HTTP service testing |

Rule of thumb: **stay in Rhai** until you need (a) a real DB / cache / IDP call, (b) a language your team already maintains, or (c) more than ~200 lines of logic. Cross either bar and the coprocessor's operational overhead pays for itself.

## What Rhai is good at

Header transformations, claim-based routing, simple request/response decorations, structured logging. The hot path stays in-process so the latency cost is negligible.

```rhai
// router.rhai — set a marker header on outbound subgraph requests
fn subgraph_service(service, subgraph){
    service.map_request(|request|{
        // Header reads/writes use indexed access; `contains` requires a
        // local binding inside subgraph_service or it throws "cannot mutate".
        let headers = request.subgraph.headers;
        if headers.contains("authorization") {
            request.subgraph.headers["x-request-from-router"] = "true";
        }
    });
}
```

The Rhai header surface only exposes the indexed accessor (read via `headers["x"]`, write via assignment) and `contains()` / `values()` (multi-value reads). There is **no `.remove()` or `.set()` method**; for header removal use the YAML [`headers.remove`](https://www.apollographql.com/docs/graphos/routing/header-propagation) plugin rather than Rhai, since it's the documented removal path.

When the rule changes you redeploy the file (or rely on file-watch hot reload). Customers love this for the iteration speed.

## What coprocessors are good at

- **Auth flows that need IdP I/O** — token introspection, refresh-grant exchange, claim enrichment from a directory.
- **Custom rate-limiting** that consults Redis or a downstream rate-limit service.
- **Audit logging** that ships structured events to Kafka / a SIEM with delivery guarantees.
- **Multi-step transformation logic** that's easier to write and test in your team's primary language.

A coprocessor is a plain HTTP server: the Router posts a JSON payload at each enabled stage and expects the same shape back, mutated. There is no Apollo SDK — the `reference-architecture` repo's own [`coprocessor/`](../coprocessor/) directory uses Express + `jose` and is the canonical example layout. A minimal claim-enrichment SupergraphRequest handler:

```javascript
// coprocessor.js — claim enrichment from an internal directory
import express from "express";

const app = express();
app.use(express.json({ limit: "5mb" }));

app.post("/", async (req, res) => {
  const payload = req.body;
  if (payload.stage === "SupergraphRequest") {
    const sub = payload.context?.entries?.["apollo::authentication::jwt_claims"]?.sub;
    if (sub) {
      const user = await directory.lookupBySub(sub);
      payload.context.entries["user_groups"] = user.groups;
    }
  }
  // Return the payload (mutated or unchanged) with the SAME shape and a 2xx —
  // a non-2xx or a shape mismatch is a "failed response" and fails the request.
  res.json(payload);
});

app.listen(4001);
```

Wire it up in `router.yaml`:

```yaml title="router.yaml — enable the coprocessor at SupergraphRequest"
coprocessor:
  url: http://127.0.0.1:4001
  timeout: 1s          # see "Failure modes" below
  supergraph:
    request:
      context: true
```

The coprocessor is deployed alongside Router (often as a sidecar in Kubernetes, or as an adjacent ECS service).

## Failure modes worth deciding upfront

For coprocessors, the Router treats any of the following as a [failed response](https://www.apollographql.com/docs/graphos/routing/customization/coprocessor) and **returns an error to the client** — i.e. fail-closed:

- The coprocessor doesn't respond inside the `coprocessor.timeout` window (defaults to **1 s**).
- The coprocessor returns a non-`2xx` HTTP code.
- The response body doesn't match the stage's JSON shape.

There is no per-stage `fail_open`/`fail_closed` toggle — so for any stage you can't afford to take down the request path (logging, telemetry, claim-enrichment that's a "nice to have"), the coprocessor itself must never throw and never time out. Catch and return the inbound payload unchanged on internal errors, and keep external I/O short-circuited (cache, short timeout) so the per-stage budget never exceeds `coprocessor.timeout`.

For Rhai, an unhandled error inside the script also fails the request. Defensive coding (`try`/`catch`) matters.

## See also

- [Router Rhai docs](https://www.apollographql.com/docs/graphos/routing/customization/rhai)
- [Router coprocessor docs](https://www.apollographql.com/docs/graphos/routing/customization/coprocessor)
- [`apollosolutions/rhai-test`](https://github.com/apollosolutions/rhai-test) — unit-test framework for Rhai scripts
- [`apollosolutions/coprocessor-examples`](https://github.com/apollosolutions/coprocessor-examples) — coprocessor starters across languages
- [`coprocessor/`](../coprocessor/) — the working coprocessor used by this reference architecture
