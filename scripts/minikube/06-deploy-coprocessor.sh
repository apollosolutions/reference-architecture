#!/bin/bash
set -euo pipefail

# Script 06: Deploy Coprocessor
# This script deploys the coprocessor using Helm
# The coprocessor is required for JWT authentication and the @authenticated directive

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
    
    echo "Local registry enabled. Will use registry image: ${REGISTRY_URL}/coprocessor:${IMAGE_TAG}"
    HELM_IMAGE_OVERRIDES="--set image.repository=${REGISTRY_URL}/coprocessor --set image.tag=${IMAGE_TAG} --set image.pullPolicy=IfNotPresent"
else
    echo "Using local Docker image (not using registry)"
fi

# Check if coprocessor image exists
echo "Checking if coprocessor image exists..."
if ! docker images | grep -q "coprocessor.*local"; then
    echo "Warning: coprocessor:local image not found"
    echo "Building coprocessor image..."
    docker build -t "coprocessor:local" "coprocessor"
    if [ $? -eq 0 ]; then
        echo "✓ Successfully built coprocessor:local"
    else
        echo "✗ Failed to build coprocessor:local"
        exit 1
    fi
fi

# If registry is enabled, tag and push the image
if [ -n "$REGISTRY_URL" ]; then
    echo "Tagging coprocessor image for registry with tag: ${IMAGE_TAG}..."
    docker tag "coprocessor:local" "${REGISTRY_URL}/coprocessor:${IMAGE_TAG}"
    docker tag "coprocessor:local" "${REGISTRY_URL}/coprocessor:local"
    
    echo "Pushing coprocessor image to registry..."
    if docker push "${REGISTRY_URL}/coprocessor:${IMAGE_TAG}"; then
        echo "✓ Successfully pushed coprocessor:${IMAGE_TAG} to registry"
        docker push "${REGISTRY_URL}/coprocessor:local" || true
    else
        echo "✗ Failed to push coprocessor to registry"
        exit 1
    fi
fi

# Deploy coprocessor using Helm
echo "Deploying coprocessor using Helm..."
helm upgrade --install coprocessor deploy/coprocessor \
    --namespace apollo \
    $HELM_IMAGE_OVERRIDES \
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
echo "Next step: Run 07-deploy-operator-resources.sh to deploy the router with coprocessor configuration"

