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

# Configure docker to use Minikube's Docker daemon
echo "Configuring Docker to use Minikube's daemon..."
eval $(minikube docker-env)

# Check if local registry is enabled
REGISTRY_URL=""
IMAGE_TAG="local"
HELM_IMAGE_OVERRIDES=""
if [[ "${USE_LOCAL_REGISTRY:-}" == "true" ]]; then
    # Verify registry service exists (Minikube addon is in kube-system namespace)
    if ! kubectl get svc registry -n kube-system &>/dev/null; then
        echo "Error: Registry service not found. Please run 03a-setup-registry.sh first"
        exit 1
    fi
    
    # Get registry ClusterIP and port dynamically
    REGISTRY_CLUSTER_IP=$(kubectl get svc registry -n kube-system -o jsonpath='{.spec.clusterIP}' 2>/dev/null || echo "")
    # Get the HTTP port (not HTTPS port 443)
    REGISTRY_PORT=$(kubectl get svc registry -n kube-system -o jsonpath='{.spec.ports[?(@.name=="http")].port}' 2>/dev/null || echo "")
    
    if [ -z "$REGISTRY_CLUSTER_IP" ]; then
        echo "Error: Could not get registry ClusterIP"
        exit 1
    fi
    
    # Error if port cannot be determined
    if [ -z "$REGISTRY_PORT" ] || [ "$REGISTRY_PORT" == "null" ]; then
        echo "Error: Could not determine registry port"
        echo "  Please ensure the registry addon is properly enabled"
        exit 1
    fi
    
    # Use ClusterIP for image references
    REGISTRY_URL="${REGISTRY_CLUSTER_IP}:${REGISTRY_PORT}"
    
    # Read image tag from file (created by script 04)
    if [ -f ".image-tag" ]; then
        IMAGE_TAG=$(head -n 1 .image-tag | tr -d '[:space:]')
        if [ -z "$IMAGE_TAG" ] || [ ${#IMAGE_TAG} -lt 8 ]; then
            echo "Warning: Invalid image tag in .image-tag, using 'local'"
            IMAGE_TAG="local"
        fi
    fi
    
    echo "Local registry enabled. Will use registry image: ${REGISTRY_URL}/client:${IMAGE_TAG}"
    HELM_IMAGE_OVERRIDES="--set image.repository=${REGISTRY_URL}/client --set image.tag=${IMAGE_TAG} --set image.pullPolicy=IfNotPresent"
else
    echo "Using local Docker image (not using registry)"
fi

# Build client with BACKEND_URL if Dockerfile supports it
RESOURCE_NAME="reference-architecture-${ENVIRONMENT}"
if [ -f "client/Dockerfile" ] && grep -q "BACKEND_URL" "client/Dockerfile"; then
    echo "Building client image with BACKEND_URL=$BACKEND_URL..."
    echo "Note: The client's nginx will proxy /graphql requests to the router service"
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
else
    # Build client image even if BACKEND_URL is not in Dockerfile
    echo "Building client image..."
    docker build -t client:local client
fi

# If registry is enabled, tag and push the image
if [ -n "$REGISTRY_URL" ]; then
    echo "Tagging client image for registry with tag: ${IMAGE_TAG}..."
    docker tag "client:local" "${REGISTRY_URL}/client:${IMAGE_TAG}"
    docker tag "client:local" "${REGISTRY_URL}/client:local"
    
    echo "Pushing client image to registry..."
    if docker push "${REGISTRY_URL}/client:${IMAGE_TAG}"; then
        echo "✓ Successfully pushed client:${IMAGE_TAG} to registry"
        docker push "${REGISTRY_URL}/client:local" || true
    else
        echo "✗ Failed to push client to registry"
        exit 1
    fi
fi

# Install using Helm
echo "Deploying client..."
helm upgrade --install client "deploy/client" \
    -n client \
    $HELM_IMAGE_OVERRIDES \
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

