#!/bin/bash
set -euo pipefail

# Script 04: Build Docker Images Locally
# This script builds all subgraph Docker images and loads them into Minikube

# Ensure script is run from repository root
if [ ! -d "scripts/minikube" ] || [ ! -d "subgraphs" ] || [ ! -d "deploy" ]; then
    echo "Error: This script must be run from the repository root directory"
    echo "Please run: ./scripts/minikube/04-build-images.sh"
    exit 1
fi

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

# Configure docker to use Minikube's Docker daemon
echo "Configuring Docker to use Minikube's daemon..."
eval $(minikube docker-env)

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
echo "Note: Images are loaded into Minikube's Docker daemon"
echo ""
echo "Next step: Run ./scripts/minikube/05-deploy-subgraphs.sh to deploy subgraphs"

