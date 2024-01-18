rover supergraph compose --config ./dev/supergraph.yaml --output ./dev/supergraph.graphql

./dev/router --config ./dev/router.yaml --supergraph ./dev/supergraph.graphql --dev
```