#!/bin/bash
set -euo pipefail

# Script 06: Deploy Operator Resources
# This script deploys SupergraphSchema and Supergraph CRDs

echo "=== Step 06: Deploying Operator Resources ==="

# Load environment variables from .env if it exists
if [ -f .env ]; then
    echo "Loading environment variables from .env..."
    source .env
fi

# Validate required variables
if [[ -z "${ENVIRONMENT:-}" ]]; then
    echo "Error: ENVIRONMENT is required"
    echo "Please set ENVIRONMENT in your .env file or export it:"
    echo "  export ENVIRONMENT=\"dev\""
    exit 1
fi

if [[ -z "${APOLLO_GRAPH_ID:-}" ]]; then
    echo "Error: APOLLO_GRAPH_ID is not set"
    echo "Please run 02-setup-apollo-graph.sh first"
    exit 1
fi

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo "Error: kubectl is not installed"
    exit 1
fi

# Verify cluster connection
if ! kubectl cluster-info &> /dev/null; then
    echo "Error: Cannot connect to Kubernetes cluster"
    exit 1
fi

# Ensure apollo namespace exists
kubectl create namespace apollo --dry-run=client -o yaml | kubectl apply -f -

# Resource name based on environment
RESOURCE_NAME="reference-architecture-${ENVIRONMENT}"

# Deploy SupergraphSchema
echo "Deploying SupergraphSchema..."
cat <<EOF | kubectl apply -f -
apiVersion: apollographql.com/v1alpha2
kind: SupergraphSchema
metadata:
  name: ${RESOURCE_NAME}
  namespace: apollo
spec:
  graphRef: ${APOLLO_GRAPH_ID}@${ENVIRONMENT}
  selectors:
    - matchExpressions:
        - key: apollo.io/subgraph
          operator: Exists
  partial: false
EOF

echo "SupergraphSchema deployed"

# Wait a moment for schema to be composed
echo "Waiting for schema composition..."
sleep 5

# Deploy Supergraph
echo "Deploying Supergraph..."
cat <<EOF | kubectl apply -f -
apiVersion: apollographql.com/v1alpha2
kind: Supergraph
metadata:
  name: ${RESOURCE_NAME}
  namespace: apollo
spec:
  replicas: 3
  podTemplate:
    routerVersion: 2.7.0
    resources:
      requests:
        cpu: 100m
        memory: 256Mi
  schema:
    resource:
      name: ${RESOURCE_NAME}
      namespace: apollo
EOF

echo "Supergraph deployed"

# Wait for router to be ready
echo "Waiting for router to be ready..."
kubectl wait --for=condition=ready --timeout=300s supergraph/${RESOURCE_NAME} -n apollo || true

echo ""
echo "✓ Operator resources deployed!"
echo ""
echo "Monitor router status with:"
echo "  kubectl get supergraphs -n apollo"
echo "  kubectl get pods -n apollo"
echo ""
echo "Next step: Run 07-deploy-ingress.sh to setup external access"

