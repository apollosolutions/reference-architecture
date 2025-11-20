#!/bin/bash
set -euo pipefail

# Script 03a: Setup Local OCI Registry (Optional)
# This script enables the Minikube registry addon for local OCI image storage
# This is an optional step - only runs if USE_LOCAL_REGISTRY is set to "true"

echo "=== Step 03a: Setting up Local OCI Registry (Optional) ==="

# Load environment variables from .env if it exists
if [ -f .env ]; then
    echo "Loading environment variables from .env..."
    source .env
fi

# Check if local registry is enabled
if [[ "${USE_LOCAL_REGISTRY:-}" != "true" ]]; then
    echo "Local registry not enabled (USE_LOCAL_REGISTRY is not set to 'true')"
    echo "Skipping registry setup..."
    echo ""
    echo "To enable local registry, add to your .env file:"
    echo "  export USE_LOCAL_REGISTRY=\"true\""
    echo ""
    exit 0
fi

echo "Local registry is enabled. Setting up Minikube registry addon..."

# Check if minikube is available
if ! command -v minikube &> /dev/null; then
    echo "Error: minikube is not installed"
    exit 1
fi

# Check if minikube is running
if ! minikube status &> /dev/null; then
    echo "Error: Minikube is not running"
    echo "Please run: minikube start"
    exit 1
fi

# Enable the registry addon
echo "Enabling Minikube registry addon..."
if minikube addons enable registry; then
    echo "✓ Registry addon enabled"
else
    echo "Error: Failed to enable registry addon"
    exit 1
fi

# Wait for registry to be ready
echo "Waiting for registry to be ready..."
for i in {1..30}; do
    if kubectl get svc registry -n kube-system &>/dev/null; then
        echo "✓ Registry service found"
        break
    fi
    if [ $i -eq 30 ]; then
        echo "Warning: Registry service not found after waiting"
    else
        echo "  Waiting for registry... ($i/30)"
        sleep 2
    fi
done

# Get registry service details
REGISTRY_CLUSTER_IP=$(kubectl get svc registry -n kube-system -o jsonpath='{.spec.clusterIP}' 2>/dev/null || echo "")
# Get the HTTP port (not HTTPS port 443)
REGISTRY_PORT=$(kubectl get svc registry -n kube-system -o jsonpath='{.spec.ports[?(@.name=="http")].port}' 2>/dev/null || echo "")

# Error if port cannot be determined
if [ -z "$REGISTRY_PORT" ] || [ "$REGISTRY_PORT" == "null" ]; then
    echo "Error: Could not determine registry port"
    echo "  Please ensure the registry addon is properly enabled"
    exit 1
fi

REGISTRY_SERVICE="registry.kube-system.svc.cluster.local:${REGISTRY_PORT}"

if [ -z "$REGISTRY_CLUSTER_IP" ]; then
    echo "Warning: Could not get registry service ClusterIP"
    echo "  Registry may still be initializing"
else
    echo "✓ Registry service details:"
    echo "  - Service DNS: ${REGISTRY_SERVICE}"
    echo "  - ClusterIP: ${REGISTRY_CLUSTER_IP}:${REGISTRY_PORT}"
    echo "  - Port: ${REGISTRY_PORT} (dynamically detected)"
fi

# Verify registry is accessible from within cluster
echo "Verifying registry is accessible from within cluster..."
for i in {1..30}; do
    if kubectl run test-registry --image=curlimages/curl --rm -i --restart=Never --namespace=kube-system --timeout=30s -- \
        curl -s --max-time 10 -o /dev/null -w "%{http_code}" http://${REGISTRY_SERVICE}/v2/ 2>/dev/null | grep -q "200\|401"; then
        echo "✓ Registry is accessible from within cluster"
        break
    fi
    if [ $i -eq 30 ]; then
        echo "Warning: Could not verify registry accessibility from cluster"
        echo "  This might be okay if Minikube networking is still initializing"
    else
        echo "  Waiting for registry... ($i/30)"
        sleep 2
    fi
done

# Clean up test pod if it still exists
kubectl delete pod test-registry -n kube-system --ignore-not-found=true &>/dev/null || true

# Check and install oras CLI if needed
echo ""
echo "Checking for oras CLI..."
if command -v oras &> /dev/null; then
    ORAS_VERSION=$(oras version 2>/dev/null | head -n 1 || echo "unknown")
    echo "✓ oras CLI is already installed: $ORAS_VERSION"
else
    echo "oras CLI not found. Installing..."
    
    # Detect OS and architecture
    OS=$(uname -s | tr '[:upper:]' '[:lower:]')
    ARCH=$(uname -m)
    
    # Map architecture
    case "$ARCH" in
        x86_64)
            ORAS_ARCH="amd64"
            ;;
        arm64|aarch64)
            ORAS_ARCH="arm64"
            ;;
        *)
            echo "Error: Unsupported architecture: $ARCH"
            echo "Please install oras manually from https://oras.land/docs/installation"
            exit 1
            ;;
    esac
    
    # Map OS
    case "$OS" in
        linux)
            ORAS_OS="linux"
            ;;
        darwin)
            ORAS_OS="darwin"
            ;;
        *)
            echo "Error: Unsupported OS: $OS"
            echo "Please install oras manually from https://oras.land/docs/installation"
            exit 1
            ;;
    esac
    
    # Get latest version
    ORAS_VERSION=$(curl -s https://api.github.com/repos/oras-project/oras/releases/latest | jq -r '.tag_name' | sed 's/^v//')
    
    if [ -z "$ORAS_VERSION" ] || [ "$ORAS_VERSION" == "null" ]; then
        echo "Warning: Could not determine latest oras version. Using 1.1.0 as fallback."
        ORAS_VERSION="1.1.0"
    fi
    
    # Download and install
    ORAS_URL="https://github.com/oras-project/oras/releases/download/v${ORAS_VERSION}/oras_${ORAS_VERSION}_${ORAS_OS}_${ORAS_ARCH}.tar.gz"
    TEMP_DIR=$(mktemp -d)
    
    echo "  Downloading oras v${ORAS_VERSION}..."
    if curl -sL "$ORAS_URL" -o "$TEMP_DIR/oras.tar.gz"; then
        echo "  Extracting..."
        tar -xzf "$TEMP_DIR/oras.tar.gz" -C "$TEMP_DIR" oras
        chmod +x "$TEMP_DIR/oras"
        
        # Install to a directory in PATH
        if [ -w "/usr/local/bin" ]; then
            sudo mv "$TEMP_DIR/oras" /usr/local/bin/oras
            echo "✓ oras installed to /usr/local/bin/oras"
        elif [ -w "$HOME/.local/bin" ]; then
            mkdir -p "$HOME/.local/bin"
            mv "$TEMP_DIR/oras" "$HOME/.local/bin/oras"
            echo "✓ oras installed to $HOME/.local/bin/oras"
            echo "  Make sure $HOME/.local/bin is in your PATH"
        else
            echo "Error: Cannot find writable directory in PATH"
            echo "Please install oras manually:"
            echo "  1. Download from: $ORAS_URL"
            echo "  2. Extract and move to a directory in your PATH"
            rm -rf "$TEMP_DIR"
            exit 1
        fi
        
        rm -rf "$TEMP_DIR"
        
        # Verify installation
        if command -v oras &> /dev/null; then
            echo "✓ oras installation verified"
        else
            echo "Warning: oras installed but not found in PATH"
            echo "  You may need to add the installation directory to your PATH"
        fi
    else
        echo "Error: Failed to download oras"
        echo "Please install oras manually from https://oras.land/docs/installation"
        rm -rf "$TEMP_DIR"
        exit 1
    fi
fi

echo ""
echo "✓ Registry configuration complete!"
echo ""
echo "Note: When using 'minikube docker-env' (as in script 04-build-images.sh), Docker runs"
echo "inside the Minikube VM and will use the ClusterIP (${REGISTRY_CLUSTER_IP}:${REGISTRY_PORT})"
echo "which is already in Docker's insecure registry range (10.96.0.0/12)."
echo ""
echo "No additional Minikube configuration is needed for Docker pushes."
echo ""

# Upgrade operator with http_only_registries configuration
echo ""
echo "Upgrading Apollo GraphOS Operator with HTTP-only registry configuration..."
if helm list -n apollo-operator | grep -q apollo-operator; then
    # Create temporary values file with ClusterIP added to http_only_registries
    TEMP_VALUES=$(mktemp)
    cat deploy/operator-resources/operator-values.yaml > "$TEMP_VALUES"
    
    # Add ClusterIP to http_only_registries if it's not already there
    if [ -n "$REGISTRY_CLUSTER_IP" ]; then
        # Use yq if available, otherwise use awk to add the ClusterIP
        if command -v yq &> /dev/null; then
            yq eval ".config.oci.http_only_registries += [\"${REGISTRY_CLUSTER_IP}:${REGISTRY_PORT}\"]" -i "$TEMP_VALUES"
        else
            # Fallback to awk: add ClusterIP after the service DNS entry under oci.http_only_registries
            awk -v clusterip="${REGISTRY_CLUSTER_IP}:${REGISTRY_PORT}" \
                '/registry\.kube-system\.svc\.cluster\.local:80/ { print; print "      - \"" clusterip "\""; next } { print }' \
                "$TEMP_VALUES" > "${TEMP_VALUES}.tmp" && mv "${TEMP_VALUES}.tmp" "$TEMP_VALUES"
        fi
        echo "  Added ClusterIP (${REGISTRY_CLUSTER_IP}:${REGISTRY_PORT}) to http_only_registries"
    fi
    
    helm upgrade apollo-operator \
        oci://registry-1.docker.io/apollograph/operator-chart \
        -n apollo-operator \
        -f "$TEMP_VALUES" \
        --wait || {
        echo "Warning: Failed to upgrade operator. You may need to upgrade it manually:"
        echo "  helm upgrade apollo-operator oci://registry-1.docker.io/apollograph/operator-chart -n apollo-operator -f deploy/operator-resources/operator-values.yaml"
    }
    echo "✓ Operator upgraded"
    
    # Clean up temporary file
    rm -f "$TEMP_VALUES"
else
    echo "⚠️  Warning: Apollo GraphOS Operator not found"
    echo "   Please run 03-setup-cluster.sh first to install the operator"
    echo "   The operator will be configured when you run this script again after installing it"
fi

echo ""
echo "✓ Local OCI registry setup complete!"
echo ""
echo "Registry URLs (HTTP):"
echo "  - From Kubernetes pods: http://${REGISTRY_SERVICE}"
if [ -n "$REGISTRY_CLUSTER_IP" ]; then
    echo "  - ClusterIP: http://${REGISTRY_CLUSTER_IP}:${REGISTRY_PORT}"
fi
echo "  - From host (with socat): http://localhost:5000"
echo ""
echo "Note:"
echo "  - The registry uses HTTP (not HTTPS)"
echo "  - The operator is configured to use HTTP-only registries"
echo "  - Images pushed to localhost:5000 will be accessible from Kubernetes pods"
echo "  - oras CLI is required for syncing supergraph schemas (installed above)"
echo ""
echo "Next step: Run 04-build-images.sh to build Docker images"
echo ""
