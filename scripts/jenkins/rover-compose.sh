#!/bin/bash
set -euo pipefail

# Helper script to run rover supergraph compose
# Usage: ./rover-compose.sh <graph-ref> [output-file]

GRAPH_REF="${1:-}"
OUTPUT_FILE="${2:-}"

if [[ -z "$GRAPH_REF" ]]; then
    echo "Usage: $0 <graph-ref> [output-file]"
    echo "Example: $0 my-graph@dev supergraph.graphql"
    exit 1
fi

# Default output file if not provided
if [[ -z "$OUTPUT_FILE" ]]; then
    OUTPUT_FILE="supergraph.graphql"
fi

echo "Composing supergraph from ${GRAPH_REF}..."

# Check if config file exists
CONFIG_FILE="scripts/jenkins/supergraph-config.yaml"
if [[ -f "$CONFIG_FILE" ]]; then
    echo "Using config file: $CONFIG_FILE"
    rover supergraph compose \
        --config "$CONFIG_FILE" \
        --output "$OUTPUT_FILE" \
        "${GRAPH_REF}"
else
    echo "No config file found, using default composition..."
    rover supergraph compose \
        --output "$OUTPUT_FILE" \
        "${GRAPH_REF}"
fi

if [[ -f "$OUTPUT_FILE" ]]; then
    echo "✅ Supergraph composed successfully: $OUTPUT_FILE"
    ls -lh "$OUTPUT_FILE"
else
    echo "❌ Error: Output file not created"
    exit 1
fi


