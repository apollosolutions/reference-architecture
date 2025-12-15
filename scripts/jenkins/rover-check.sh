#!/bin/bash
set -euo pipefail

# Helper script to run rover subgraph check
# Usage: ./rover-check.sh <subgraph-name> <graph-ref>

SUBGRAPH_NAME="${1:-}"
GRAPH_REF="${2:-}"

if [[ -z "$SUBGRAPH_NAME" ]] || [[ -z "$GRAPH_REF" ]]; then
    echo "Usage: $0 <subgraph-name> <graph-ref>"
    echo "Example: $0 checkout my-graph@dev"
    exit 1
fi

SCHEMA_FILE="subgraphs/${SUBGRAPH_NAME}/schema.graphql"

if [[ ! -f "$SCHEMA_FILE" ]]; then
    echo "Error: Schema file not found: $SCHEMA_FILE"
    exit 1
fi

echo "Checking ${SUBGRAPH_NAME} subgraph against ${GRAPH_REF}..."

cd "subgraphs/${SUBGRAPH_NAME}"

rover subgraph check "${GRAPH_REF}" \
    --name "${SUBGRAPH_NAME}" \
    --schema schema.graphql

echo "✅ ${SUBGRAPH_NAME} subgraph check passed"

