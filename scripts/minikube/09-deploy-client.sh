#!/bin/bash
set -euo pipefail

# Script 09: Deploy Client
# This script deploys the client application (optional)

echo "=== Step 09: Deploying Client Application ==="

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

# Get router URL from .env file
if [[ -z "${ROUTER_URL:-}" ]]; then
    echo "Error: ROUTER_URL is not set"
    echo "Please run 08-setup-router-access.sh first to set up the router URL"
    exit 1
fi

BACKEND_URL="$ROUTER_URL"
echo "Using backend URL: $BACKEND_URL"

# Create client namespace
kubectl create namespace client --dry-run=client -o yaml | kubectl apply -f -

# Check if client directory exists
if [ ! -d "client" ]; then
    echo "Warning: client directory not found, skipping client deployment"
    exit 0
fi

# Build client with BACKEND_URL if Dockerfile supports it
RESOURCE_NAME="reference-architecture-${ENVIRONMENT}"
if [ -f "client/Dockerfile" ] && grep -q "BACKEND_URL" "client/Dockerfile"; then
    echo "Building client image with BACKEND_URL=$BACKEND_URL..."
    echo "Note: The client's nginx will proxy /graphql requests to the router service"
    eval $(minikube docker-env)
    # Backup original nginx config
    cp client/docker/nginx/conf.d/default.conf client/docker/nginx/conf.d/default.conf.bak
    # Replace placeholder with actual service name (handle both macOS and Linux sed)
    if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i '' "s/\${ROUTER_SERVICE_NAME}/$RESOURCE_NAME/g" client/docker/nginx/conf.d/default.conf
    else
        sed -i "s/\${ROUTER_SERVICE_NAME}/$RESOURCE_NAME/g" client/docker/nginx/conf.d/default.conf
    fi
    # Verify the replacement worked
    if grep -q "\${ROUTER_SERVICE_NAME}" client/docker/nginx/conf.d/default.conf; then
        echo "Warning: Placeholder replacement may have failed. Checking config..."
        cat client/docker/nginx/conf.d/default.conf
    fi
    # Build without cache to ensure nginx config is included
    docker build --no-cache --build-arg BACKEND_URL="$BACKEND_URL" -t client:local client
    # Restore original nginx config
    mv client/docker/nginx/conf.d/default.conf.bak client/docker/nginx/conf.d/default.conf
fi

# Install using Helm
echo "Deploying client..."
helm upgrade --install client "deploy/client" \
    -n client \
    --wait

# Force pod restart to pick up new image
echo "Restarting client pods to pick up new image..."
kubectl rollout restart deployment/web -n client
kubectl rollout status deployment/web -n client --timeout=120s

# The Helm chart already creates an ingress resource named "web"
# Check if ingress exists and get its status
echo "Checking client ingress status..."
CLIENT_INGRESS_NAME="web"
CLIENT_IP=""
for i in {1..30}; do
    CLIENT_IP=$(kubectl get ingress ${CLIENT_INGRESS_NAME} -n client -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
    if [ -n "$CLIENT_IP" ]; then
        break
    fi
    echo "  Waiting for ingress IP... ($i/30)"
    sleep 2
done

if [ -z "$CLIENT_IP" ]; then
    echo ""
    echo "Warning: Client ingress did not get an IP address after waiting"
    echo "The ingress may still be configuring. Check status with:"
    echo "  kubectl get ingress ${CLIENT_INGRESS_NAME} -n client"
    echo ""
else
    echo ""
    echo "✓ Client is accessible at:"
    echo "  http://${CLIENT_IP}"
    echo ""
    echo "If using minikube tunnel, access at: http://127.0.0.1/"
    echo "(The client ingress uses the same LoadBalancer as the router)"
    echo ""
fi

