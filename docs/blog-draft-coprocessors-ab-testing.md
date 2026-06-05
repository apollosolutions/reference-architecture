# Blog draft — A/B testing at the graph with Apollo Router coprocessors

> Draft for the Apollo blog. Tracks [AS-322](https://apollographql.atlassian.net/browse/AS-322). Companion code lives at [`apollosolutions/coprocessor-examples`](https://github.com/apollosolutions/coprocessor-examples) under the existing examples layout — recommend adding an `ab-testing/` directory there.

---

## A/B testing at the graph: route experiments with Apollo Router coprocessors

A/B testing usually lives in one of two places: at the CDN edge, where it can flip CSS but doesn't know which user is on which experiment by the time the API call lands, or in the application code itself, where the experiment logic ends up scattered across services. Neither works cleanly for a federated graph that fans out to multiple subgraphs per request.

There's a third option: do it at the Apollo Router with a coprocessor. The Router already sees every request before any subgraph fetch, has access to client identity and JWT claims, and supports per-subgraph routing decisions. A small coprocessor turns it into an experimentation control plane.

### The setup

We'll route 10% of traffic for an authenticated user pool to a "v2" implementation of a `recommendations` subgraph, leaving the other 90% on v1. The decision is made in a coprocessor, attached to the request as context, and consumed by the subgraph service step to override the routing URL.

```
client ─► Router ─► [coprocessor: assign experiment bucket] ─► subgraph fetch
                                                              │
                                                              └─► if bucket=v2: recommendations-v2
                                                                  else:        recommendations-v1
```

### Coprocessor: assignment logic

The coprocessor receives the SupergraphRequest payload from the Router, extracts the JWT subject claim, runs a deterministic hash to bucket the user, and writes the result into the request context.

```javascript
// coprocessor/ab-router.js
import { ApolloRouterCoprocessor } from "@apollo/router-coprocessor";
import { createHash } from "node:crypto";

const EXPERIMENT_KEY = "recs-v2";
const ROLLOUT_PCT = 10;

const bucket = (userId) => {
  const h = createHash("sha256").update(`${EXPERIMENT_KEY}:${userId}`).digest();
  return h.readUInt32BE(0) % 100;
};

new ApolloRouterCoprocessor()
  .onSupergraphRequest((req) => {
    const userId = req.context.entries.jwt_claims?.sub;
    if (!userId) return req; // unauthenticated → default branch

    const variant = bucket(userId) < ROLLOUT_PCT ? "v2" : "v1";
    req.context.entries.experiment_recs = variant;
    req.headers["x-experiment-recs"] = variant;
    return req;
  })
  .listen(4001);
```

A deterministic hash on `(experiment name, user id)` keeps a user in the same bucket across requests without needing a database, which matters: re-bucketing a user mid-session is the most common source of weird A/B telemetry.

### Router: route on the context entry

```yaml title="router.yaml"
coprocessor:
  url: http://coprocessor:4001
  supergraph:
    request:
      context: true
      headers: true

override_subgraph_url:
  recommendations: http://recommendations.default.svc.cluster.local:4000
  recommendations-v2: http://recommendations-v2.default.svc.cluster.local:4000

# Per-subgraph routing override based on the context entry the coprocessor set.
traffic_shaping:
  subgraphs:
    recommendations:
      rules:
        - when:
            context: experiment_recs
            equals: v2
          target_subgraph: recommendations-v2
```

(The `traffic_shaping.rules` block is illustrative — see the [Router subgraph routing customization docs](https://www.apollographql.com/docs/router/configuration/overview) for the current syntax. The same effect is achievable with a Rhai script in `subgraph_service`.)

### Observing the experiment

Two things make experiments observable on the graph:

1. **Telemetry attribute** — instrument the supergraph span with `experiment_recs` as an attribute:

   ```yaml
   telemetry:
     instrumentation:
       instruments:
         router:
           http.server.request.duration:
             attributes:
               experiment_recs:
                 request_context: experiment_recs
   ```

2. **Studio operation report** — set `apollographql-client-name` based on the variant so operations from each branch are filterable in Studio.

From there, your downstream analytics pipeline (Amplitude / Mixpanel / a homegrown event store) joins on the user id and the variant to produce the result.

### Why this is better than per-app A/B

- The decision is made **once per request**, not once per app surface, so a user is on the same experiment whether they're on web, iOS, or Android.
- Subgraph teams don't need to be aware of the experiment — they ship `v1` and `v2` and the graph routes between them.
- Tear-down is one config change; no app release to remove the dead branch.
- Observability is automatic: every metric the Router already emits carries the experiment dimension.

### Caveats

- Coprocessors add latency (~1–10 ms typical). For 100% deterministic routing on a hot path, prefer Rhai (see [Router customizations](./router-customizations.md)).
- Sticky bucketing across services requires that every service consume the same hash key, otherwise the user can be in two buckets at once across the request lifecycle.
- The hash-based assignment doesn't support targeted rollouts (e.g. "only US users"). For those, the coprocessor needs to consult a feature-flag service like Flagsmith, LaunchDarkly, or Statsig.

### Try it

The companion code lives under [`apollosolutions/coprocessor-examples`](https://github.com/apollosolutions/coprocessor-examples) — recommended PR to add `ab-testing/` alongside the existing language examples. The router config and a Node coprocessor stub fit in ~50 lines combined.

---

## Editorial notes

- Final post should land on apollographql.com/blog. The `traffic_shaping.rules` block needs to be reconciled against the actual Router config surface (current syntax may use `override_subgraph_url` with a context-based selector — verify before publishing).
- Companion repo PR scope: small Node coprocessor (~60 lines) + `router.yaml` + README.

Tracks [AS-322](https://apollographql.atlassian.net/browse/AS-322).
