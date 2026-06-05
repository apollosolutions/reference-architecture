# Graph for agentic AI workflows (MCP)

> Why a federated graph is the right substrate for agentic AI tool calling, and what changes about graph design when LLMs are the consumers. Tracks [AS-320](https://apollographql.atlassian.net/browse/AS-320).

LLM agents do work by calling tools. [MCP](https://modelcontextprotocol.io/) is the protocol that exposes tools to those agents. The Apollo MCP server fronts a GraphOS Router and turns its persisted operations into MCP tools — which means the graph is, by definition, the agent's API.

This shifts a few of the rules that hold for human-driven graph consumption.

## What changes when the consumer is an LLM

| | Human consumer | LLM consumer |
| --- | --- | --- |
| **Schema discovery** | One-time learning curve, persisted in their head. | Done on every conversation. Tool descriptions are read fresh by the model each turn. |
| **Field-name quality** | Matters at code-review time. | Matters at _every inference_. Bad names cause wrong tool calls. |
| **Operation count** | Limited by what you ship as PQs. | Limited by what fits in the model's context. Too many tools → worse selection. |
| **Argument typing** | Compiler catches mistakes. | Model has to infer types from descriptions. Optional vs required matters more. |
| **Errors** | Devs read stack traces. | LLM re-tries blindly until it gets a 200. Make errors instruct on the fix. |

## Architecture: Router + MCP server + agent

```
LLM agent ──MCP──► apollo-mcp-server ──graphql──► Apollo Router ──► federated subgraphs
                       │
                       │ exposes one MCP tool per
                       │ persisted operation in
                       │ the graph manifest
                       ▼
                  GraphOS (operation registry)
```

The MCP server reads the Router's persisted operations manifest. Each PQ becomes one MCP tool, with:
- the operation name → tool name
- the operation description (GraphQL doc-comment on the operation) → tool description for the model
- the operation variables → tool input schema

Authorization, telemetry, caching, and tracing all stay where they already live in the Router. The MCP layer is presentational.

See the working example in [`apollosolutions/apollo-mcp-server`](https://github.com/apollosolutions/apollo-mcp-server) and the in-repo coprocessor wiring in [`deploy/apollo-mcp-server/`](../deploy/apollo-mcp-server/).

## Graph design changes when LLMs are first-class

### Name operations from the agent's point of view

`searchProductsByQuery` reads to an LLM as "this returns matches to a search query." `productSearch` is ambiguous (is it a UI search box? full-text? semantic?). The latter is fine for humans who can ask a teammate; LLMs hallucinate the disambiguation. Prefer **verb + object + qualifier**.

### Use the operation's GraphQL description as the tool description

```graphql
"""
Find products that match a free-text search query.
Pass a short shopper-style phrase (e.g. "wireless earbuds under 100 dollars").
Returns up to `limit` products ranked by relevance.
"""
query SearchProductsByQuery($query: String!, $limit: Int = 10) {
  searchProducts(query: $query, limit: $limit) { … }
}
```

The MCP server lifts this string into the tool's description. The model reads it on every turn — keep it specific, name the units (dollars, kg, ISO 8601), and call out edge cases the model would otherwise guess at.

### Shrink the tool surface to what the agent should see

A 50-subgraph supergraph might publish thousands of operations. Don't expose all of them. Curate a small persisted-operations manifest tagged for agentic use — typically a few dozen high-signal operations, not a thousand thin queries.

The Router's [contract variants](https://www.apollographql.com/docs/graphos/delivery/contracts/) are a clean way to materialise this — one variant per agent persona, each with its own narrowed schema and operation set.

### Make errors readable to the model

LLMs treat `errors[0].message` as the only signal for "try again differently." A message of `"variable Query.searchProducts.limit must be greater than 0"` will steer the model. `"Invalid arguments"` will not. Apply this to subgraph-level `@apollo/server` errors too — the Router propagates them by default.

### Cache aggressively

Agents repeat themselves more than humans do — they often re-issue the same tool call to verify their own work. Entity caching (see [Entity caching best practices](./entity-caching-best-practices.md)) cuts a lot of redundant subgraph traffic when the consumer is an LLM.

## Authorization for agents

Two patterns we recommend:

1. **Per-agent service account** — the agent calls Router with its own API key / JWT. Useful when you have a small number of well-known agents.
2. **On-behalf-of token exchange** — the agent calls with the end-user's token, and a coprocessor in the Router exchanges it for the subgraph-appropriate token. Required for any agent that acts as a particular user. The [`example-router-obo-flow`](https://github.com/apollosolutions/example-router-obo-flow) repo is the canonical reference.

Don't give the agent a privileged token directly. The blast radius of a prompt-injected agent making un-scoped GraphQL calls is large.

## Observability

The Router emits the standard `graphql.operation.name` attribute on every operation it sees, plus the `apollographql-client-name` header carried through telemetry. Wire `apollographql-client-name: <agent-name>` from the MCP server so:

- Studio operation reports can filter agent traffic separately from human traffic.
- Rate limits can target agents specifically.
- A misbehaving agent is identifiable in 30 s, not 30 min.

## See also

- [`apollosolutions/apollo-mcp-server`](https://github.com/apollosolutions/apollo-mcp-server)
- [`apollosolutions/agui-solutions-demo`](https://github.com/apollosolutions/agui-solutions-demo) — multi-vertical agentic UI demo
- [`apollosolutions/lending-graph-ai-demo`](https://github.com/apollosolutions/lending-graph-ai-demo) — MCP + Calendar agentic example
- [Entity caching best practices](./entity-caching-best-practices.md)
- [MCP Production Guide](./mcp-production.md) — IdP, scopes, networking when you take the demo to prod
- [`example-router-obo-flow`](https://github.com/apollosolutions/example-router-obo-flow) — on-behalf-of token exchange in a coprocessor
