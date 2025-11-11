#!/bin/bash
set -euo pipefail

# Script 07: Deploy Operator Resources
# This script deploys SupergraphSchema and Supergraph CRDs
# Note: The coprocessor (script 06) must be deployed first as the router requires it

echo "=== Step 07: Deploying Operator Resources ==="

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

# Create router configuration ConfigMap
echo "Creating router configuration ConfigMap..."
kubectl create configmap router-config \
    --from-file=router.yaml=deploy/operator-resources/router-config.yaml \
    -n apollo \
    --dry-run=client -o yaml | kubectl apply -f -

echo "Router configuration ConfigMap created"

# Create Rhai scripts ConfigMap
echo "Creating Rhai scripts ConfigMap..."
kubectl create configmap rhai-scripts \
    --from-file=main.rhai=deploy/operator-resources/rhai/main.rhai \
    -n apollo \
    --dry-run=client -o yaml | kubectl apply -f -

echo "Rhai scripts ConfigMap created"

# Deploy SupergraphSchema
echo "Deploying SupergraphSchema..."

# Use environment-specific SupergraphSchema file
SUPERGRAPHSCHEMA_FILE="deploy/operator-resources/supergraphschema-${ENVIRONMENT}.yaml"
if [ -f "${SUPERGRAPHSCHEMA_FILE}" ]; then
    echo "Using environment-specific SupergraphSchema file: ${SUPERGRAPHSCHEMA_FILE}"
    sed "s/\${APOLLO_GRAPH_ID}/${APOLLO_GRAPH_ID}/g" "${SUPERGRAPHSCHEMA_FILE}" | kubectl apply -f -
else
    echo "Error: SupergraphSchema file not found for environment: ${ENVIRONMENT}"
    echo "Expected file: ${SUPERGRAPHSCHEMA_FILE}"
    exit 1
fi

echo "SupergraphSchema deployed"

# Wait a moment for schema to be composed
echo "Waiting for schema composition..."
sleep 5

# Deploy Supergraph with ConfigMap-mounted router configuration
# The router configuration is loaded from the ConfigMap and mounted as a volume
# The router will use the --config flag to reference the mounted file
echo "Deploying Supergraph..."

# Check for environment-specific Supergraph file first, then use template
SUPERGRAPH_FILE="deploy/operator-resources/supergraph-${ENVIRONMENT}.yaml"
if [ -f "${SUPERGRAPH_FILE}" ]; then
    echo "Using environment-specific Supergraph file: ${SUPERGRAPH_FILE}"
    kubectl apply -f "${SUPERGRAPH_FILE}"
else
    echo "Using Supergraph template: deploy/operator-resources/supergraph.yaml.template"
    sed "s/\${RESOURCE_NAME}/${RESOURCE_NAME}/g" deploy/operator-resources/supergraph.yaml.template | kubectl apply -f -
fi

echo "Supergraph deployed"

# Wait for router deployment to be created
echo "Waiting for router deployment to be created..."
DEPLOYMENT_NAME="${RESOURCE_NAME}"
for i in {1..60}; do
    if kubectl get deployment ${DEPLOYMENT_NAME} -n apollo &>/dev/null; then
        echo "Router deployment found"
        break
    fi
    echo "  Waiting for deployment... ($i/60)"
    sleep 2
done

if ! kubectl get deployment ${DEPLOYMENT_NAME} -n apollo &>/dev/null; then
    echo "Error: Router deployment not found after waiting"
    echo "Please check the Supergraph status:"
    echo "  kubectl get supergraph ${RESOURCE_NAME} -n apollo"
    exit 1
fi

echo ""
echo "✓ Operator resources deployed!"
echo ""
echo "SupergraphSchema and Supergraph CRDs have been created."
echo "The router deployment is being created by the operator."
echo ""
echo "Monitor router status with:"
echo "  kubectl get supergraphs -n apollo"
echo "  kubectl get pods -n apollo"
echo ""
echo "Next step: Run 08-apply-router-config.sh to configure the router with custom settings"

