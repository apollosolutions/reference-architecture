#!/bin/bash
set -euo pipefail

# Script 07: Deploy Ingress
# This script sets up ingress for external access to the router

echo "=== Step 07: Deploying Ingress ==="

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

# Verify cluster connection
if ! kubectl cluster-info &> /dev/null; then
    echo "Error: Cannot connect to Kubernetes cluster"
    exit 1
fi

# Check if ingress addon is enabled
if ! minikube addons list | grep -q "ingress.*enabled"; then
    echo "Enabling ingress addon..."
    minikube addons enable ingress
    echo "Waiting for ingress controller to be ready..."
    sleep 15
fi

# Wait for ingress controller pods to be ready
echo "Waiting for ingress controller to be ready..."
kubectl wait --namespace ingress-nginx \
    --for=condition=ready pod \
    --selector=app.kubernetes.io/component=controller \
    --timeout=120s || {
    echo "Warning: Ingress controller may not be fully ready"
}

# Resource name based on environment
RESOURCE_NAME="reference-architecture-${ENVIRONMENT}"

# Ensure apollo namespace exists
kubectl create namespace apollo --dry-run=client -o yaml | kubectl apply -f -

# Deploy Ingress
echo "Deploying Ingress for router..."
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: router
  namespace: apollo
spec:
  ingressClassName: nginx
  rules:
    - http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: ${RESOURCE_NAME}
                port:
                  number: 80
EOF

echo "Ingress deployed"

# Wait for ingress to get an IP address
echo "Waiting for ingress to get an IP address..."
INGRESS_IP=""
for i in {1..30}; do
    INGRESS_IP=$(kubectl get ingress router -n apollo -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
    if [ -n "$INGRESS_IP" ]; then
        break
    fi
    echo "  Waiting for ingress IP... ($i/30)"
    sleep 2
done

if [ -z "$INGRESS_IP" ]; then
    echo ""
    echo "Error: Ingress did not get an IP address after waiting"
    echo "This may indicate an issue with the ingress controller"
    echo ""
    echo "Troubleshooting:"
    echo "  1. Check ingress controller status: kubectl get pods -n ingress-nginx"
    echo "  2. Check ingress status: kubectl describe ingress router -n apollo"
    echo "  3. Try restarting ingress: minikube addons disable ingress && minikube addons enable ingress"
    exit 1
fi

echo ""
echo "✓ Router is accessible at:"
echo "  http://${INGRESS_IP}"
echo ""
echo "You can access the router at the IP above. If you want to use a hostname instead,"
echo "you can add this to your /etc/hosts file:"
echo "  ${INGRESS_IP}  router.local"
echo ""
echo "Then access at: http://router.local"

