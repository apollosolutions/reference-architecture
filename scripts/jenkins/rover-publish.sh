#!/bin/bash
set -euo pipefail

# Helper script to run rover subgraph publish
# Usage: ./rover-publish.sh <subgraph-name> <graph-ref> [routing-url]

SUBGRAPH_NAME="${1:-}"
GRAPH_REF="${2:-}"
ROUTING_URL="${3:-}"

if [[ -z "$SUBGRAPH_NAME" ]] || [[ -z "$GRAPH_REF" ]]; then
    echo "Usage: $0 <subgraph-name> <graph-ref> [routing-url]"
    echo "Example: $0 checkout my-graph@dev http://graphql.checkout.svc.cluster.local:4001"
    exit 1
fi

SCHEMA_FILE="subgraphs/${SUBGRAPH_NAME}/schema.graphql"

if [[ ! -f "$SCHEMA_FILE" ]]; then
    echo "Error: Schema file not found: $SCHEMA_FILE"
    exit 1
fi

# Default routing URL if not provided
if [[ -z "$ROUTING_URL" ]]; then
    ROUTING_URL="http://graphql.${SUBGRAPH_NAME}.svc.cluster.local:4001"
fi

echo "Publishing ${SUBGRAPH_NAME} subgraph to ${GRAPH_REF}..."
echo "Routing URL: ${ROUTING_URL}"

cd "subgraphs/${SUBGRAPH_NAME}"

rover subgraph publish "${GRAPH_REF}" \
    --name "${SUBGRAPH_NAME}" \
    --schema schema.graphql \
    --routing-url "${ROUTING_URL}"

echo "✅ ${SUBGRAPH_NAME} subgraph published successfully"


