# Choosing organizational boundaries for subgraphs

> Drawing the line between subgraphs is an organizational decision before it is a technical one. Tracks [AS-325](https://apollographql.atlassian.net/browse/AS-325).

Federation lets you split a graph as many ways as you want. The hard part is deciding _how_. This guide covers the four boundary models we see in customer engagements, their trade-offs, and the failure mode each one tends to produce.

> [!NOTE]
> Designed as a follow-on to the [monolith-to-federation guide](https://www.apollographql.com/docs/graphos/schema-design/guides/from-monolith). That guide gets you from one schema to several; this one helps you decide _which_ several.

## The four boundary models

### 1. By team

Each subgraph is owned by one team and the boundary is wherever team ownership changes.

- **Best when** Conway's Law is already in effect. The team that owns the `Orders` service in their existing architecture owns the `Orders` subgraph in the federated one.
- **Failure mode** Teams that share data end up with awkward circular `@requires` dependencies because the boundary cuts through a single logical entity.
- **Looks like** `team-orders/`, `team-fulfillment/`, `team-payments/` — names are owners' names.

This is the most popular starting model and we recommend it unless one of the others fits much better.

### 2. By domain

Subgraphs are organized around business domains. Multiple teams may contribute to one subgraph; one team may own multiple subgraphs.

- **Best when** the company is organized around business domains (DDD shops, large enterprises with overlapping engineering responsibilities).
- **Failure mode** "Who owns it" becomes ambiguous fast. The `Customer` subgraph has six committers from four teams and PRs sit.
- **Looks like** `commerce/`, `identity/`, `inventory/` — names are business concepts.

### 3. By data source

One subgraph per backing data source (one for the PostgreSQL writes, one for the REST orchestration layer, one for the analytics warehouse, etc.).

- **Best when** the limiting factor is data-source-specific orchestration logic (rate limiting, connection pooling, schema migrations).
- **Failure mode** Cross-cutting business concepts (e.g. `Product`) appear in multiple subgraphs because their data lives in multiple places, and federation routes around it with `@external`/`@requires` chains.
- **Looks like** `postgres-orchestrator/`, `stripe-proxy/`, `warehouse-bi/` — names are sources, not concepts.

### 4. By usage pattern (or "shape")

Subgraphs split by who consumes them — public API, internal admin, mobile-optimized.

- **Best when** the graph genuinely has multiple consumer cohorts with different schemas. Contracts are usually a better answer here.
- **Failure mode** You end up reimplementing the same entity three ways, with field-level inconsistencies. _Use contracts instead of separate subgraphs_ for the multi-consumer case.

## A decision flow

```
                 Will the same team own everything in this part of the graph?
                          │
              Yes ────────┴──────── No
               │                     │
               ▼                     ▼
   Is the domain boundary    Are the consumers
   _also_ a team boundary?   substantially different?
        │                          │
   Yes──┴──No              Yes─────┴─────No
    │     │                 │             │
    ▼     ▼                 ▼             ▼
 by team  by domain   contracts +    by team
                      shared subgraph (default)
```

When in doubt, ship **by team** and refactor when the pain becomes specific. Federation makes this refactor relatively cheap (it's mostly moving `@key`s around) — don't pre-optimize.

## Sizing heuristics

- **Too big** if one subgraph has more than ~30 types or ~3 teams committing to it. The PR queue becomes a bottleneck.
- **Too small** if a subgraph exists solely to expose one type with one resolver. The federation overhead (rover publish, CI step, deploy pipeline) costs more than the type is worth — merge it.
- **Goldilocks** is usually 5–20 types, one team, one deploy cadence. The reference architecture in this repo follows this pattern.

## The reorganization conversation

When you're consolidating multiple subgraphs into one (or splitting one into many), the right sequence is:

1. **Decide ownership first.** Don't move types until the team that will own them is committed.
2. **Use `@override(from: ...)` for the migration.** This lets you move fields incrementally without breaking composition. See TN0024 for the deprecation pattern.
3. **Delete the old subgraph last**, only after the new one is fully serving its traffic and the old fields have been removed from clients.
4. **Run a check before each step.** `rover subgraph check` catches the federation-composition regressions before they hit prod.

## See also

- [Monolith to Federation guide](https://www.apollographql.com/docs/graphos/schema-design/guides/from-monolith) — the natural starting point this builds on
- [TN0012 Namespacing by separation of concern](https://www.apollographql.com/docs/technotes/TN0012-namespacing-by-separation-of-concern/)
- [TN0036 Owner pattern](https://www.apollographql.com/docs/technotes/TN0036-owner-pattern/)
- [Apollo Contracts](https://www.apollographql.com/docs/graphos/delivery/contracts/) — the right answer for the "by usage pattern" case
- [Advanced schema design](./advanced-schema-design.md) (AS-323)
