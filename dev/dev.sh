if [[ -z "${APOLLO_KEY}" ]]; then
  echo "APOLLO_KEY is not set"
  exit 1
fi
if [[ -z "${APOLLO_GRAPH_REF}" ]]; then
  echo "APOLLO_GRAPH_REF is not set"
  exit 1
fi

if [ ! -f "./dev/router" ]; then
    cd dev
    curl -sSL https://router.apollo.dev/download/nix/v2.2.0 | sh 
    cd ..
fi

rover supergraph compose --config ./dev/supergraph.yaml --output ./dev/supergraph.graphql

./dev/router --config ./dev/router.yaml --supergraph ./dev/supergraph.graphql --dev
