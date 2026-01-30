#!/bin/bash
set -euo pipefail

# Script 07: Deploy Redis (for Apollo Router response caching)
# This script installs Redis into a dedicated "redis" namespace using Helm.

# Ensure script is run from repository root
if [ ! -d "scripts/minikube" ] || [ ! -d "subgraphs" ] || [ ! -d "deploy" ]; then
    echo "Error: This script must be run from the repository root directory"
    echo "Please run: ./scripts/minikube/07-deploy-redis.sh"
    exit 1
fi

echo "=== Step 07: Deploying Redis (Helm) ==="

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

# Ensure redis namespace exists
kubectl create namespace redis --dry-run=client -o yaml | kubectl apply -f -

echo "Installing Redis Helm chart..."
helm upgrade --install --atomic --wait redis \
    oci://registry-1.docker.io/bitnamicharts/redis \
    -n redis \
    --create-namespace \
    --set architecture=standalone \
    --set auth.enabled=false \
    --set master.persistence.enabled=false

echo "Waiting for Redis to be ready..."
kubectl rollout status statefulset/redis-master -n redis --timeout=300s

echo ""
echo "✓ Redis deployed!"
echo ""
echo "Service DNS (in-cluster): redis-master.redis.svc.cluster.local:6379"
echo ""
echo "Next step: Run ./scripts/minikube/08-deploy-operator-resources.sh to deploy Supergraph resources"

