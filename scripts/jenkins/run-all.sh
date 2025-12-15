#!/bin/bash
set -euo pipefail

# Master script to run all Rover commands
# Usage: ./run-all.sh [environment]
# Example: ./run-all.sh dev

ENVIRONMENT="${1:-dev}"

# Load environment variables from .env if it exists
if [[ -f "../../.env" ]]; then
    echo "Loading environment variables from .env..."
    source ../../.env
fi

# Validate required variables
if [[ -z "${APOLLO_KEY:-}" ]]; then
    echo "Error: APOLLO_KEY is not set"
    echo "Please set APOLLO_KEY in your environment or .env file"
    exit 1
fi

if [[ -z "${APOLLO_GRAPH_ID:-}" ]]; then
    echo "Error: APOLLO_GRAPH_ID is not set"
    echo "Please set APOLLO_GRAPH_ID in your environment or .env file"
    exit 1
fi

GRAPH_REF="${APOLLO_GRAPH_ID}@${ENVIRONMENT}"

# Subgraphs to process (comma-separated, default: checkout only)
# Can be overridden via SUBGRAPHS environment variable
# Example: SUBGRAPHS="checkout,discovery" ./scripts/jenkins/run-all.sh dev
SUBGRAPHS_STR="${SUBGRAPHS:-checkout}"

# Convert comma-separated string to array
IFS=',' read -ra SUBGRAPHS_ARRAY <<< "$SUBGRAPHS_STR"
SUBGRAPHS=("${SUBGRAPHS_ARRAY[@]}")

echo "=========================================="
echo "Running Rover CI/CD Pipeline"
echo "Environment: ${ENVIRONMENT}"
echo "Graph Reference: ${GRAPH_REF}"
echo "Subgraphs: ${SUBGRAPHS_STR}"
echo "=========================================="
echo ""

# Ensure we're in the repository root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
cd "$REPO_ROOT"

# Check if Rover is installed
if ! command -v rover &> /dev/null; then
    echo "Rover CLI not found. Installing..."
    curl -sSL https://rover.apollo.dev/nix/latest | sh
    export PATH="$HOME/.rover/bin:$PATH"
fi

echo "Rover version:"
rover --version
echo ""

# Stage 1: Subgraph Check
echo "=========================================="
echo "Stage 1: Checking all subgraphs"
echo "=========================================="
echo ""

FAILED_CHECKS=0
for subgraph in "${SUBGRAPHS[@]}"; do
    echo "Checking ${subgraph}..."
    if ./scripts/jenkins/rover-check.sh "${subgraph}" "${GRAPH_REF}"; then
        echo "✅ ${subgraph} check passed"
    else
        echo "❌ ${subgraph} check failed"
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
    fi
    echo ""
done

if [[ $FAILED_CHECKS -gt 0 ]]; then
    echo "❌ ${FAILED_CHECKS} subgraph check(s) failed. Aborting."
    exit 1
fi

echo "✅ All subgraph checks passed!"
echo ""

# Stage 2: Subgraph Publish
echo "=========================================="
echo "Stage 2: Publishing all subgraphs"
echo "=========================================="
echo ""

FAILED_PUBLISHES=0
for subgraph in "${SUBGRAPHS[@]}"; do
    echo "Publishing ${subgraph}..."
    if ./scripts/jenkins/rover-publish.sh "${subgraph}" "${GRAPH_REF}"; then
        echo "✅ ${subgraph} published"
    else
        echo "❌ ${subgraph} publish failed"
        FAILED_PUBLISHES=$((FAILED_PUBLISHES + 1))
    fi
    echo ""
done

if [[ $FAILED_PUBLISHES -gt 0 ]]; then
    echo "❌ ${FAILED_PUBLISHES} subgraph publish(es) failed. Aborting."
    exit 1
fi

echo "✅ All subgraphs published successfully!"
echo ""

# Stage 3: Supergraph Compose
echo "=========================================="
echo "Stage 3: Composing supergraph"
echo "=========================================="
echo ""

OUTPUT_FILE="supergraph-${ENVIRONMENT}.graphql"
if ./scripts/jenkins/rover-compose.sh "${GRAPH_REF}" "${OUTPUT_FILE}"; then
    echo "✅ Supergraph composed successfully!"
    echo "Output: ${OUTPUT_FILE}"
else
    echo "❌ Supergraph composition failed"
    exit 1
fi

echo ""
echo "=========================================="
echo "✅ All stages completed successfully!"
echo "=========================================="

