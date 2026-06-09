# Advanced schema design for federated graphs

> For teams that have shipped Federation and now need to scale the schema across multiple domains, teams, and consumer surfaces. Tracks [AS-323](https://apollographql.atlassian.net/browse/AS-323).

The Apollo public docs cover the basics (`@key`, `@requires`, `@provides`, contracts). This note covers the design questions that come up once the graph is in production and the failure modes are political as much as technical.

## Stop adding root types — federate around entities, not endpoints

The most common Day-2 anti-pattern is the "second `Query.users` problem": team A owns `users`, team B needs to extend it with their own data, and someone proposes `Query.allUsers` or `Query.usersV2` to side-step the ownership conversation.

Resist this. The federation answer is `@key` on `User` and an `extend type User` in the consuming subgraph. New root fields are a smell unless they actually return a different conceptual entity. If you find yourself reaching for `Query.usersV2`, the real question is whether the existing `User` should split into two entities or get a new namespace (see TN0012).

## One write, one entity, one owner

A field that mutates state should live in exactly one subgraph. Once two subgraphs both expose `Mutation.updateUser(...)`, you cannot reason about ordering, partial failures, or idempotency.

If two teams legitimately need to write to the same entity, the model is:
1. One subgraph owns the write surface for the entity.
2. Other teams contribute write operations via that subgraph (calling internal APIs or sending events) — not via federated mutations.

Read fan-out is what federation handles cleanly. Write fan-out across federated mutations is not what it's for.

## Nullability discipline

Federation increases the surface area where nullable becomes load-bearing. The two rules that prevent the most pain:

1. **`@key` values must be present at runtime.** Federation composes subgraphs whose key fields are SDL-nullable (the spec does not require `@key` fields to be declared non-null), and a missing key at runtime is treated as "entity not found" rather than a hard error. Declaring keys non-null in SDL is still strongly recommended — it documents the invariant, lets clients reason about response shape, and catches mistakes at composition rather than at request time.
2. **Nullable scalar fields are not the default** — they should reflect a specific business meaning ("this user has not been onboarded yet"), not "this field might fail to fetch." Subgraphs returning errors should return `null` for the field and add an entry to `errors`, not return a `null` representing "we made it up."

See TN0023 for the long version.

## Pagination

Federation amplifies the cost of bad pagination because entity refetches re-trigger the upstream pagination call. Three patterns, in increasing complexity:

- **Cursor + page-size, no total count.** Cheapest. Use when the client doesn't need a "X of Y" indicator.
- **Cursor + page-size + total count.** Total count costs an extra DB query per request — expose it only on a `pageInfo.totalCount` field so clients can opt out.
- **Relay-style connections (`edges`, `node`, `pageInfo`).** Verbose, but mandatory when you need cursor-based pagination across federated subgraphs and clients use Apollo Client's normalized cache. See TN0029.

Don't expose `offset` pagination on entities with `@key`. Offsets shift under concurrent writes and break entity caching badly.

## Errors-as-data for partial-failure cases

A subgraph returning a partial result with one bad field gets two choices:
1. Throw a GraphQL error, return null for the bad field — the field shows up in `errors[]`.
2. Make the field type a union of the success case and a domain-specific error type — the field returns successfully and the response shape carries the error.

Pattern (2) is the [errors-as-data](https://www.apollographql.com/docs/technotes/TN0041-errors-as-data-explained/) pattern. Use it for **expected failure modes** — auth, business rule violations, validation errors. Use (1) for **unexpected** failures — subgraph down, database error, timeout.

The crime is using (1) for expected failures. Clients then have to parse `errors[]` for business logic, which makes the contract opaque and the typing useless.

## @shareable, @override, @inaccessible — the three least-understood directives

- `@shareable` — explicit opt-in for "this field can be resolved by more than one subgraph." Without it, federation refuses to compose two subgraphs that both define the same field. Use it only on fields where the value is identical regardless of which subgraph resolves it (e.g. `Product.id`, computed totals).

- `@override(from: "old-subgraph")` — explicit migration directive. Lets the new subgraph claim ownership of a field while the old subgraph still defines it, allowing for a smooth cutover. Typically followed by deletion of the field from the old subgraph in a follow-up release, though [progressive `@override`](https://www.apollographql.com/docs/federation/entities-advanced/#incremental-migration-with-override) (percentage-based traffic rollout) is also supported as an intermediate step before full cutover.

- `@inaccessible` — hides a field from the public API surface without removing it from subgraph internals. Useful during deprecation or for fields that exist for federation-internal reasons (e.g. join keys that aren't meant to be queried directly).

## Versioning

The right answer is almost always "don't" — federate around evolving the existing schema with `@deprecated`. The wrong answer that keeps coming back: `Query.userV2`, `Query.userV3`, `Query.user_new`. Every one of these makes deprecation harder and bloats the schema indefinitely.

The legitimate use cases for an explicit version split:
- Breaking type changes (enum value renamed, type changed). Even then, prefer additive deprecation.
- Different consumer cohorts that need different shapes — that's a [contract](https://www.apollographql.com/docs/graphos/delivery/contracts/), not a versioned type.

## See also

- [TN0012 Namespacing by separation of concern](https://www.apollographql.com/docs/technotes/TN0012-namespacing-by-separation-of-concern/)
- [TN0023 Nullability](https://www.apollographql.com/docs/technotes/TN0023-nullability/)
- [TN0024 Deprecations](https://www.apollographql.com/docs/technotes/TN0024-deprecations/)
- [TN0027 Demand-oriented schema design](https://www.apollographql.com/docs/technotes/TN0027-demand-oriented-schema-design/)
- [TN0029 Relay-style connections](https://www.apollographql.com/docs/technotes/TN0029-relay-style-connections/)
- [TN0041 Errors as data explained](https://www.apollographql.com/docs/technotes/TN0041-errors-as-data-explained/)
