#!/bin/bash
set -euo pipefail

# Script 08: Deploy Client
# This script deploys the client application (optional)

echo "=== Step 08: Deploying Client Application ==="

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

# Get router URL for backend configuration
RESOURCE_NAME="reference-architecture-${ENVIRONMENT}"
INGRESS_IP=$(kubectl get ingress router -n apollo -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")

if [ -z "$INGRESS_IP" ]; then
    echo "Error: Router ingress not found or has no IP address"
    echo "Please ensure script 07-deploy-ingress.sh completed successfully"
    exit 1
fi

BACKEND_URL="http://${INGRESS_IP}"
echo "Using backend URL: $BACKEND_URL"

# Create client namespace
kubectl create namespace client --dry-run=client -o yaml | kubectl apply -f -

# Check if client directory exists
if [ ! -d "client" ]; then
    echo "Warning: client directory not found, skipping client deployment"
    exit 0
fi

# Build client with BACKEND_URL if Dockerfile supports it
if [ -f "client/Dockerfile" ] && grep -q "BACKEND_URL" "client/Dockerfile"; then
    echo "Building client image with BACKEND_URL=$BACKEND_URL..."
    eval $(minikube docker-env)
    docker build --build-arg BACKEND_URL="$BACKEND_URL" -t client:local client
fi

# Install using Helm
echo "Deploying client..."
helm upgrade --install client "deploy/client" \
    -n client \
    --wait

# Deploy ingress for client
echo "Deploying ingress for client..."
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: client
  namespace: client
spec:
  ingressClassName: nginx
  rules:
    - http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: web
                port:
                  number: 80
EOF

echo "Client ingress deployed"

# Wait for ingress to get an IP address
echo "Waiting for client ingress to get an IP address..."
CLIENT_IP=""
for i in {1..30}; do
    CLIENT_IP=$(kubectl get ingress client -n client -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
    if [ -n "$CLIENT_IP" ]; then
        break
    fi
    echo "  Waiting for ingress IP... ($i/30)"
    sleep 2
done

if [ -z "$CLIENT_IP" ]; then
    echo ""
    echo "Error: Client ingress did not get an IP address after waiting"
    echo "This may indicate an issue with the ingress controller"
    echo ""
    echo "Troubleshooting:"
    echo "  1. Check ingress controller status: kubectl get pods -n ingress-nginx"
    echo "  2. Check ingress status: kubectl describe ingress client -n client"
    exit 1
fi

echo ""
echo "✓ Client is accessible at:"
echo "  http://${CLIENT_IP}"
echo ""
echo "You can access the client at the IP above. If you want to use a hostname instead,"
echo "you can add this to your /etc/hosts file:"
echo "  ${CLIENT_IP}  client.local"
echo ""
echo "Then access at: http://client.local"
echo ""
echo "✓ Client deployment complete!"

