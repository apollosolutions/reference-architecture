#!/bin/bash
set -euo pipefail

# This script applies the operator resources with the correct graph ID
# Usage: ./apply-resources.sh {dev|prod}

ENVIRONMENT=${1:-dev}

if [[ "$ENVIRONMENT" != "dev" && "$ENVIRONMENT" != "prod" ]]; then
  echo "Error: Environment must be 'dev' or 'prod'"
  exit 1
fi

# Check if TF_VAR_apollo_graph_id is set
if [[ -z "${TF_VAR_apollo_graph_id:-}" ]]; then
  echo "Error: TF_VAR_apollo_graph_id is not set. Please source .env file from your terraform directory."
  exit 1
fi

echo "Deploying operator resources for ${ENVIRONMENT} environment with graph ID: ${TF_VAR_apollo_graph_id}"

# Apply SupergraphSchema with graph ID substitution
if command -v envsubst &> /dev/null; then
  envsubst < "supergraphschema-${ENVIRONMENT}.yaml" | kubectl apply -f -
else
  # Fallback if envsubst not available
  sed "s|\${TF_VAR_apollo_graph_id}|${TF_VAR_apollo_graph_id}|g" "supergraphschema-${ENVIRONMENT}.yaml" | kubectl apply -f -
fi

# Apply Supergraph
kubectl apply -f "supergraph-${ENVIRONMENT}.yaml"

# Apply Ingress
kubectl apply -f "ingress-${ENVIRONMENT}.yaml"

echo "Operator resources deployed successfully for ${ENVIRONMENT} environment"

