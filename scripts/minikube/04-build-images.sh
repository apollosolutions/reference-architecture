#!/bin/bash
set -euo pipefail

# Script 04: Build Docker Images Locally
# This script builds all subgraph Docker images and loads them into Minikube

echo "=== Step 04: Building Docker Images Locally ==="

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

# Check if docker is available
if ! command -v docker &> /dev/null; then
    echo "Error: docker is not installed"
    exit 1
fi

# Check if minikube is running
if ! minikube status &> /dev/null; then
    echo "Error: Minikube is not running"
    echo "Please run: minikube start"
    exit 1
fi

# Configure docker to use Minikube's Docker daemon for building
echo "Configuring Docker to use Minikube's daemon for building..."
eval $(minikube docker-env)

# Check if local registry is enabled
REGISTRY_URL=""
REGISTRY_URL_FOR_DOCKER=""
IMAGE_TAG="local"
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
    
    # Use ClusterIP for Docker daemon (we're using minikube docker-env, so Docker is in Minikube VM)
    # ClusterIP is in the 10.96.0.0/12 range which is already in Docker's insecure registries
    # This avoids needing to configure --insecure-registry for the Minikube IP
    REGISTRY_URL_FOR_DOCKER="${REGISTRY_CLUSTER_IP}:${REGISTRY_PORT}"
    # Use service DNS for Kubernetes resources (pods can resolve it) - HTTP
    REGISTRY_URL="registry.kube-system.svc.cluster.local:${REGISTRY_PORT}"
    
    echo "Local registry enabled (HTTP)."
    echo "  - Registry for Docker: ${REGISTRY_URL_FOR_DOCKER} (ClusterIP, using minikube docker-env)"
    echo "  - Registry service DNS: ${REGISTRY_URL} (for Kubernetes pods)"
    echo "  - Registry ClusterIP: ${REGISTRY_CLUSTER_IP}:${REGISTRY_PORT}"
    echo "  - Port: ${REGISTRY_PORT} (dynamically detected)"
    echo ""
    echo "Note: Using ClusterIP for Docker pushes (within 10.96.0.0/12 insecure registry range)"
    echo ""
    
    # Verify registry is accessible from Minikube's Docker daemon
    echo "Verifying registry is accessible from Minikube..."
    if ! curl -s --max-time 5 http://${REGISTRY_URL_FOR_DOCKER}/v2/ > /dev/null 2>&1; then
        echo "⚠️  Warning: Registry may not be accessible at ${REGISTRY_URL_FOR_DOCKER}"
        echo "  The registry addon may still be initializing"
        echo "  Continuing anyway..."
    else
        echo "✓ Registry is accessible from Minikube"
    fi
    
    # Generate unique tag for this build based on timestamp
    IMAGE_TAG=$(date +%s | shasum -a 256 | head -c 12)
    echo "Using timestamp-based hash as image tag: ${IMAGE_TAG}"
    
    # Save tag to file for use in other scripts (overwrite any existing content)
    echo "${IMAGE_TAG}" > .image-tag
    echo "Image tag saved to .image-tag: ${IMAGE_TAG}"
fi

# List of subgraphs
SUBGRAPHS=("checkout" "discovery" "inventory" "orders" "products" "reviews" "shipping" "users")

# Build each subgraph image
for subgraph in "${SUBGRAPHS[@]}"; do
    echo ""
    echo "Building ${subgraph} image..."
    
    if [ ! -d "subgraphs/${subgraph}" ]; then
        echo "Warning: subgraphs/${subgraph} directory not found, skipping..."
        continue
    fi
    
    # Build the image
    docker build -t "${subgraph}:local" "subgraphs/${subgraph}"
    
    if [ $? -eq 0 ]; then
        echo "✓ Successfully built ${subgraph}:local"
        
        # If registry is enabled, tag and push directly from Minikube's Docker
        if [ -n "$REGISTRY_URL_FOR_DOCKER" ]; then
            echo "Tagging image for registry with tag: ${IMAGE_TAG}..."
            docker tag "${subgraph}:local" "${REGISTRY_URL_FOR_DOCKER}/${subgraph}:${IMAGE_TAG}"
            # Also keep :local tag for backward compatibility
            docker tag "${subgraph}:local" "${REGISTRY_URL_FOR_DOCKER}/${subgraph}:local"
            
            echo "Pushing ${subgraph} image to registry..."
            if docker push "${REGISTRY_URL_FOR_DOCKER}/${subgraph}:${IMAGE_TAG}"; then
                echo "✓ Successfully pushed ${subgraph}:${IMAGE_TAG} to registry"
                # Also push :local tag
                docker push "${REGISTRY_URL_FOR_DOCKER}/${subgraph}:local" || true
            else
                echo "✗ Failed to push ${subgraph} to registry"
                exit 1
            fi
        fi
    else
        echo "✗ Failed to build ${subgraph}:local"
        exit 1
    fi
done

# Build coprocessor image (for future use)
echo ""
echo "Building coprocessor image..."
if [ -d "coprocessor" ]; then
    docker build -t "coprocessor:local" "coprocessor"
    if [ $? -eq 0 ]; then
        echo "✓ Successfully built coprocessor:local"
        
        # If registry is enabled, tag and push directly from Minikube's Docker
        if [ -n "$REGISTRY_URL_FOR_DOCKER" ]; then
            echo "Tagging coprocessor image for registry with tag: ${IMAGE_TAG}..."
            docker tag "coprocessor:local" "${REGISTRY_URL_FOR_DOCKER}/coprocessor:${IMAGE_TAG}"
            docker tag "coprocessor:local" "${REGISTRY_URL_FOR_DOCKER}/coprocessor:local"
            
            echo "Pushing coprocessor image to registry..."
            if docker push "${REGISTRY_URL_FOR_DOCKER}/coprocessor:${IMAGE_TAG}"; then
                echo "✓ Successfully pushed coprocessor:${IMAGE_TAG} to registry"
                docker push "${REGISTRY_URL_FOR_DOCKER}/coprocessor:local" || true
            else
                echo "✗ Failed to push coprocessor to registry"
                exit 1
            fi
        fi
    else
        echo "✗ Failed to build coprocessor:local"
        exit 1
    fi
else
    echo "Warning: coprocessor directory not found, skipping..."
fi

# Build client image (for future use)
echo ""
echo "Building client image..."
if [ -d "client" ]; then
    docker build -t "client:local" "client"
    if [ $? -eq 0 ]; then
        echo "✓ Successfully built client:local"
        
        # If registry is enabled, tag and push directly from Minikube's Docker
        if [ -n "$REGISTRY_URL_FOR_DOCKER" ]; then
            echo "Tagging client image for registry with tag: ${IMAGE_TAG}..."
            docker tag "client:local" "${REGISTRY_URL_FOR_DOCKER}/client:${IMAGE_TAG}"
            docker tag "client:local" "${REGISTRY_URL_FOR_DOCKER}/client:local"
            
            echo "Pushing client image to registry..."
            if docker push "${REGISTRY_URL_FOR_DOCKER}/client:${IMAGE_TAG}"; then
                echo "✓ Successfully pushed client:${IMAGE_TAG} to registry"
                docker push "${REGISTRY_URL_FOR_DOCKER}/client:local" || true
            else
                echo "✗ Failed to push client to registry"
                exit 1
            fi
        fi
    else
        echo "✗ Failed to build client:local"
        exit 1
    fi
else
    echo "Warning: client directory not found, skipping..."
fi

echo ""
echo "✓ All images built successfully!"
echo ""
if [ -n "$REGISTRY_URL_FOR_DOCKER" ]; then
    echo "Note: Images are loaded into Minikube's Docker daemon and pushed to registry"
    echo "Registry URL (for Docker): ${REGISTRY_URL_FOR_DOCKER}"
    echo "Registry URL (for Kubernetes): ${REGISTRY_URL}"
    echo "Image tag: ${IMAGE_TAG}"
    echo "Tag saved to .image-tag for use in deployment scripts"
else
    echo "Note: Images are loaded into Minikube's Docker daemon"
fi
echo ""
echo "Next step: Run 05-deploy-subgraphs.sh to deploy subgraphs"

