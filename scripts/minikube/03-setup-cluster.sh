#!/bin/bash
set -euo pipefail

# Script 03: Setup Kubernetes Cluster
# This script sets up namespaces, installs the Apollo GraphOS Operator, and creates secrets

echo "=== Step 03: Setting up Kubernetes Cluster ==="

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

if [[ -z "${OPERATOR_KEY:-}" ]]; then
    echo "Error: OPERATOR_KEY is not set"
    echo "Please run 02-setup-apollo-graph.sh first to generate the operator key"
    exit 1
fi

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo "Error: kubectl is not installed"
    exit 1
fi

# Check if helm is available
if ! command -v helm &> /dev/null; then
    echo "Error: helm is not installed"
    echo "Please install helm: https://helm.sh/docs/intro/install/"
    exit 1
fi

# Verify cluster connection
echo "Verifying cluster connection..."
if ! kubectl cluster-info &> /dev/null; then
    echo "Error: Cannot connect to Kubernetes cluster"
    echo "Please ensure Minikube is running: minikube start"
    exit 1
fi

# Create namespaces
echo "Creating namespaces..."
kubectl create namespace apollo-operator --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace apollo --dry-run=client -o yaml | kubectl apply -f -

# Create operator API key secret
echo "Creating operator API key secret..."
kubectl create secret generic apollo-api-key \
    --from-literal="APOLLO_KEY=$OPERATOR_KEY" \
    -n apollo-operator \
    --dry-run=client -o yaml | kubectl apply -f -

echo "Operator API key secret created"

# Install Apollo GraphOS Operator using Helm
echo "Installing Apollo GraphOS Operator..."
helm upgrade --install --atomic apollo-operator \
    oci://registry-1.docker.io/apollograph/operator-chart \
    -n apollo-operator \
    --create-namespace \
    --wait \
    -f - <<EOF
apiKey:
  secretName: apollo-api-key
config:
  controllers:
    supergraph:
      apiKeySecret: apollo-api-key
EOF

echo "Apollo GraphOS Operator installed successfully"

# Wait for operator to be ready
echo "Waiting for operator to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/apollo-operator -n apollo-operator

echo ""
echo "✓ Kubernetes cluster setup complete!"
echo ""
echo "Next step: Run 04-build-images.sh to build Docker images locally"

