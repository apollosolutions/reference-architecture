#!/bin/bash
set -euo pipefail

# Script 06: Deploy Coprocessor
# This script deploys the coprocessor using Helm
# The coprocessor is required for JWT authentication and the @authenticated directive

# Ensure script is run from repository root
if [ ! -d "scripts/minikube" ] || [ ! -d "subgraphs" ] || [ ! -d "deploy" ]; then
    echo "Error: This script must be run from the repository root directory"
    echo "Please run: ./scripts/minikube/06-deploy-coprocessor.sh"
    exit 1
fi

echo "=== Step 06: Deploying Coprocessor ==="

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

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo "Error: kubectl is not installed"
    exit 1
fi

# Check if helm is available
if ! command -v helm &> /dev/null; then
    echo "Error: helm is not installed"
    exit 1
fi

# Verify cluster connection
if ! kubectl cluster-info &> /dev/null; then
    echo "Error: Cannot connect to Kubernetes cluster"
    exit 1
fi

# Ensure apollo namespace exists
kubectl create namespace apollo --dry-run=client -o yaml | kubectl apply -f -

# Check if coprocessor image exists
echo "Checking if coprocessor image exists..."
if ! docker images | grep -q "coprocessor.*local"; then
    echo "Warning: coprocessor:local image not found"
    echo "Building coprocessor image..."
    eval $(minikube docker-env)
    docker build -t "coprocessor:local" "coprocessor"
    if [ $? -eq 0 ]; then
        echo "✓ Successfully built coprocessor:local"
    else
        echo "✗ Failed to build coprocessor:local"
        exit 1
    fi
fi

# Deploy coprocessor using Helm
echo "Deploying coprocessor using Helm..."
helm upgrade --install coprocessor deploy/coprocessor \
    --namespace apollo \
    --wait \
    --timeout 5m

if [ $? -eq 0 ]; then
    echo "✓ Coprocessor deployed successfully"
else
    echo "✗ Failed to deploy coprocessor"
    exit 1
fi

# Wait for coprocessor pods to be ready
echo "Waiting for coprocessor pods to be ready..."
kubectl wait --for=condition=ready pod \
    -l app.kubernetes.io/name=coprocessor \
    -n apollo \
    --timeout=300s || true

# Check coprocessor service
echo "Checking coprocessor service..."
kubectl get svc coprocessor -n apollo

echo ""
echo "✓ Coprocessor deployment complete!"
echo ""
echo "Coprocessor is now available at:"
echo "  http://coprocessor.apollo.svc.cluster.local:8081"
echo ""
echo "Next step: Run ./scripts/minikube/07-deploy-operator-resources.sh to deploy the router with coprocessor configuration"

