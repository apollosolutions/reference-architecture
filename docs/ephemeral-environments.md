# Ephemeral environments with GraphOS

> Spin up a fully composed supergraph per PR (and tear it down on merge or close), without manual GraphOS plumbing. Tracks [AS-222](https://apollographql.atlassian.net/browse/AS-222).

Ephemeral envs let a reviewer hit a real Router + subgraph URL that reflects exactly the change in a PR. The Apollo-native primitive that makes this work is the [GraphOS variant](https://www.apollographql.com/docs/graphos/graphs#variants) — each variant has its own composed supergraph schema, its own Router config, and its own usage stats.

## Topology

```
                  ┌──────────────────────────────────┐
                  │ GraphOS                          │
PR #142 push ──►  │ variant: pr-142   ◄──┐           │
                  │ variant: main         │ rover    │
                  │ variant: prod         │ publish  │
                  └────────────────┬──────┘          │
                                   │                 │
   CI                              ▼                 │
   ──► spin up Router pointed at variant pr-142      │
       deploy subgraph services on pr-142.example    │
       comment PR with the env URL                   │
                                                     │
PR merged / closed ──► tear down namespace ──► rover graph delete my-graph@pr-142
```

One variant per PR, one short-lived Router + subgraph deployment per PR, automatic cleanup on PR close.

## Step 1 — Variant lifecycle in CI

On `pull_request: [opened, synchronize, reopened]`:

```bash
# Create the variant by publishing one subgraph against it. The variant is
# implicitly created on first publish; no separate "create variant" call.
rover subgraph publish my-graph@pr-${PR_NUMBER} \
  --name products \
  --schema ./subgraphs/products/schema.graphql \
  --routing-url https://pr-${PR_NUMBER}.products.example.com
```

On `pull_request: [closed]`:

```bash
# Delete the variant and all its subgraphs — wipes the composed supergraph,
# usage data, checks history, and any contracts. `rover graph delete` exits
# non-zero if the variant doesn't exist, so guard the step with `|| true`
# (or skip it if the variant was never created on this PR).
rover graph delete my-graph@pr-${PR_NUMBER} --confirm || true
```

The variant key (`pr-<number>`) is the contract between CI and infrastructure. Use the GitHub-provided `PR_NUMBER`, not a sha or branch name, so re-pushes still target the same variant.

## Step 2 — Subgraph deployment

Same pattern as your prod deploy, parameterized by PR number. On Kubernetes, that's a per-PR namespace; on Fly.io / Render, it's per-PR apps named `pr-<n>-products`, `pr-<n>-reviews`, etc.

The only Apollo-specific config: each subgraph's `routing-url` published to GraphOS must resolve from the Router pod. For Kubernetes, that's the in-cluster service DNS; for Fly.io/Cloud Run, the public HTTPS URL.

## Step 3 — Router pointing at the variant

The Router fetches its supergraph schema and config from Apollo Uplink based on `APOLLO_GRAPH_REF`. Set it to the per-PR variant:

```yaml
env:
  - name: APOLLO_GRAPH_REF
    value: my-graph@pr-142
  - name: APOLLO_KEY
    valueFrom:
      secretKeyRef: { name: apollo-key, key: APOLLO_KEY }
```

Router automatically refetches when the variant's supergraph schema changes (every re-push during the PR's life). No restart needed.

## Step 4 — PR comment with the URL

After the deploy completes, post a comment with the ephemeral URL. Use a deduped marker so re-pushes update the comment instead of creating new ones — the pattern in [`apollosolutions/proposal-pr-bot`](https://github.com/apollosolutions/proposal-pr-bot) works here.

## Permissions

Use a [GraphOS service account API key](https://www.apollographql.com/docs/graphos/api-keys/) scoped to one graph. The key needs:

- `graph admin` or `graph contributor` to publish subgraphs to new variants
- `graph admin` to delete variants

Store it as a GitHub Actions secret. Rotate quarterly.

## Cost / quota awareness

- **Variants are unlimited** on enterprise plans but each one counts as an active variant on usage-based plans. Tear them down promptly on PR close.
- **Usage reporting** from PR Routers is real usage data. Filter it out of dashboards by `graph.variant_id` to avoid polluting prod metrics.
- **Checks** against ephemeral variants don't carry forward to prod — the validity of a `pr-142` check expires when the variant is deleted.

## See also

- [Apollo Connectors and Router on each variant](https://www.apollographql.com/docs/graphos/graphs/federated-graphs)
- [Service accounts and API keys](https://www.apollographql.com/docs/graphos/api-keys/)
- [`apollosolutions/proposal-pr-bot`](https://github.com/apollosolutions/proposal-pr-bot) — companion tooling for keeping PR ↔ proposal in sync (AS-89)
