# How to query an existing graph

> A walkthrough for first-time consumers: someone whose team owns a new app, but whose graph already exists, run by someone else. Tracks [AS-337](https://apollographql.atlassian.net/browse/AS-337).

> [!NOTE]
> Written for a reader who hasn't used GraphQL before. Assumes they can read JSON and run a curl command, nothing more.

This guide walks through, in order:

1. Finding the graph and getting credentials.
2. Discovering what data is available.
3. Writing your first query.
4. Wiring it into your app.
5. What changes when you move from prototype to production.

## 1. Find the graph and get credentials

Ask the graph-owning team for:

| What | Why |
| --- | --- |
| The **graph's HTTPS URL** | Where your queries get sent. Usually `https://graph.<company>.com/graphql` or similar. |
| A **client name** to use in headers (`apollographql-client-name`) | Tells the graph who's calling — used for operation reports, rate limits, and quotas. Pick a stable name like `mobile-android-v1`. |
| An **authentication mechanism** | Most graphs use a JWT. The owning team will tell you how to obtain one (often the same SSO you use for everything else). |

If your team isn't onboarded with a client name yet, ask before you write code — running unbranded traffic against a federated graph makes you invisible in usage reports and is the first thing the owning team will flag.

## 2. Discover what data is available

The graph has a **schema** — a written list of all the data you can ask for and all the things you can do. The way to read it depends on how the graph is set up:

- **Apollo Studio Explorer** — if the owning team has shared a Studio variant with you, open it. The Explorer lets you browse fields, see field-level documentation, and run queries against the live graph from the browser. This is the easiest way in.
- **Sandbox** — if the graph is publicly reachable and introspection is enabled, you can go to `https://studio.apollographql.com/sandbox/explorer?endpoint=<the-graph-url>` and browse the schema from there.
- **Schema download** — for an offline reference, ask for the published SDL or use `rover graph fetch <graph-id>@<variant>`.

Browse. Look for:
- Queries that match what your app needs (`Query.userById`, `Query.searchProducts`, etc.).
- Field-level descriptions (graph owners write these for exactly this purpose — read them).
- Required arguments vs optional ones. Required ones are marked with `!`.

## 3. Write your first query

A query asks for fields. Start small.

```graphql
query GetMyProfile {
  viewer {
    id
    name
    email
  }
}
```

Run it from the Explorer or via curl:

```bash
curl https://graph.example.com/graphql \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${MY_JWT}" \
  -H "apollographql-client-name: my-app-v1" \
  -d '{"query":"query GetMyProfile { viewer { id name email } }"}'
```

You'll get back JSON with the exact shape of the query. That mirror-image property is the GraphQL contract — only the fields you ask for come back, no extras.

**Iterate**. Add a field at a time. If you ask for a field that doesn't exist, the error tells you so. If you forget a required argument, same.

## 4. Wire it into your app

Most apps use a GraphQL client library rather than raw `fetch`. The big benefit: client-side caching of normalized entities, so navigating between screens that share data doesn't re-fetch.

- **Web / React / React Native** → [Apollo Client](https://www.apollographql.com/docs/react/)
- **iOS** → [Apollo iOS](https://www.apollographql.com/docs/ios/)
- **Android / Kotlin** → [Apollo Kotlin](https://www.apollographql.com/docs/kotlin/)
- **Server / backend service** → straight HTTP is usually fine; clients there have less to do.

A minimal Apollo Client (React) setup:

```javascript
import { ApolloClient, InMemoryCache, HttpLink, from } from "@apollo/client";
import { setContext } from "@apollo/client/link/context";

const httpLink = new HttpLink({ uri: "https://graph.example.com/graphql" });
const authLink = setContext((_, { headers }) => ({
  headers: {
    ...headers,
    authorization: `Bearer ${getJWT()}`,
    "apollographql-client-name": "my-app-v1",
    "apollographql-client-version": "1.0.0",
  },
}));

export const client = new ApolloClient({
  link: from([authLink, httpLink]),
  cache: new InMemoryCache(),
});
```

The `client-name` and `client-version` headers become Studio filters for every metric the graph emits about your traffic. Set them deliberately from day one.

## 5. From prototype to production

Three things change between "I got a query working" and "production traffic":

1. **Persisted Queries.** The graph owners may require you to ship your operation list ahead of release (see Apollo's [Persisted Queries](https://www.apollographql.com/docs/graphos/routing/security/persisted-queries) docs). Plan for a build-time step that extracts your operations and publishes them. Don't ship an app that constructs queries dynamically — that's the fastest way to be blocked at deploy time.
2. **Rate limits and quotas.** Production graphs limit traffic per client. Ask what your budget is. If you're going to send 10 qps in production, run a load test against staging first.
3. **Error handling.** GraphQL returns `200 OK` for most failures, with errors in the `errors[]` array. Don't assume `200` means "everything worked." Check both `data` and `errors`.

## Common stumbles

- **Asking for too much**: a query with 100 fields and 5 levels of nesting is correct GraphQL but bad practice. Ask only for what you'll render.
- **Forgetting variables**: hardcoded values in queries make the query non-cacheable. Use `$variables` from the start.
- **Looking for fields you can't see**: if a field exists but you can't access it, the graph's authorization is filtering it out. Ask the owning team what scopes/roles you need.

## See also

- [Apollo Client docs](https://www.apollographql.com/docs/react/)
- [Apollo Persisted Queries](https://www.apollographql.com/docs/graphos/routing/security/persisted-queries) and [Automatic Persisted Queries](https://www.apollographql.com/docs/graphos/routing/operations/apq)
- [TN0038 Updating client schema](https://www.apollographql.com/docs/technotes/TN0038-updating-client-schema/)
- [`apollosolutions/graphos-feature-template`](https://github.com/apollosolutions/graphos-feature-template) — clone-it-to-learn-it template
