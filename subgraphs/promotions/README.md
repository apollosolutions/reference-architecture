# Promotions Connector Subgraph

This subgraph uses [Apollo Connectors](https://www.apollographql.com/docs/graphos/connectors/) to extend the `Product` entity with promotion data from the promotions REST API. Unlike the other subgraphs in this architecture, it has no GraphQL server—the Apollo Router executes the Connector logic directly.

## Schema

The schema in `schema.graphql` defines:

- `@source` for the promotions REST API base URL
- `extend type Product` with a `promotions` field resolved via `@connect`
- `Promotion` and `PromotionDiscountType` types

## Deployment

The promotions subgraph is deployed as a Subgraph CRD with inline SDL by `scripts/minikube/05-deploy-subgraphs.sh`. It uses `http://ignore` as the endpoint (a placeholder for Connectors—the router does not call a GraphQL server). The actual REST API URL is defined in the schema's `@source` directive.

## Data Source

The [promotions-api](../../services/promotions-api) service provides the REST API that this Connector calls.
