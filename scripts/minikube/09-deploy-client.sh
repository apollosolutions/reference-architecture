#!/bin/bash
set -euo pipefail

# Script 09: Deploy Client
# This script deploys the client application and sets up port-forwarding

# Ensure script is run from repository root
if [ ! -d "scripts/minikube" ] || [ ! -d "subgraphs" ] || [ ! -d "deploy" ]; then
    echo "Error: This script must be run from the repository root directory"
    echo "Please run: ./scripts/minikube/09-deploy-client.sh"
    exit 1
fi

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
    echo "Please run ./scripts/minikube/08-setup-router-access.sh first to set up the router URL"
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
    echo "Note: The client will use the port-forwarded router URL"
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

# Check if client service exists
CLIENT_SERVICE="web"
if ! kubectl get service "$CLIENT_SERVICE" -n client &> /dev/null; then
    echo "Error: Client service '$CLIENT_SERVICE' not found in namespace 'client'"
    exit 1
fi

# Set up port-forwarding for client
CLIENT_PORT_FORWARD_PORT=3000
CLIENT_PF_PID_FILE=".client-port-forward.pid"

# Clean up existing PID file and any stale process
if [ -f "$CLIENT_PF_PID_FILE" ]; then
    OLD_PID=$(cat "$CLIENT_PF_PID_FILE" 2>/dev/null | head -n 1 | tr -d '[:space:]' || echo "")
    if [ -n "$OLD_PID" ] && kill -0 "$OLD_PID" 2>/dev/null; then
        echo "Found existing port-forward process (PID: $OLD_PID). Stopping it..."
        kill "$OLD_PID" 2>/dev/null || true
        sleep 2
    fi
    rm -f "$CLIENT_PF_PID_FILE"
fi

# Check if port-forward is already running on this port
if lsof -ti:${CLIENT_PORT_FORWARD_PORT} &> /dev/null; then
    echo "Port ${CLIENT_PORT_FORWARD_PORT} is already in use. Checking if it's a kubectl port-forward..."
    # Try to find kubectl port-forward processes for this service
    EXISTING_PF=$(ps aux | grep "kubectl port-forward.*${CLIENT_SERVICE}.*${CLIENT_PORT_FORWARD_PORT}" | grep -v grep | awk '{print $2}' || echo "")
    if [ -n "$EXISTING_PF" ]; then
        echo "Found existing port-forward (PID: $EXISTING_PF). Stopping it..."
        kill $EXISTING_PF 2>/dev/null || true
        sleep 2
    else
        echo "Warning: Port ${CLIENT_PORT_FORWARD_PORT} is in use by another process"
        echo "Please free the port or use a different port"
        exit 1
    fi
fi

# Start port-forwarding in the background
echo "Starting port-forward for client service..."
nohup kubectl port-forward service/$CLIENT_SERVICE -n client ${CLIENT_PORT_FORWARD_PORT}:80 > /dev/null 2>&1 &
CLIENT_PORT_FORWARD_PID=$!
# Disown the process so it continues after script exits
disown $CLIENT_PORT_FORWARD_PID 2>/dev/null || true

# Wait a moment for port-forward to establish
sleep 3

# Verify port-forward is running
if ! kill -0 $CLIENT_PORT_FORWARD_PID 2>/dev/null; then
    echo "Error: Client port-forward failed to start"
    exit 1
fi

# Test if the port is accessible
if ! lsof -ti:${CLIENT_PORT_FORWARD_PORT} &> /dev/null; then
    echo "Warning: Client port-forward started but port ${CLIENT_PORT_FORWARD_PORT} is not accessible"
    echo "Port-forward PID: $CLIENT_PORT_FORWARD_PID"
else
    echo "✓ Client port-forward is running (PID: $CLIENT_PORT_FORWARD_PID)"
fi

# Save PID to a file for cleanup later
echo "$CLIENT_PORT_FORWARD_PID" > "$CLIENT_PF_PID_FILE"

# Output summary
echo ""
echo "✓ Client deployed successfully!"
echo ""
echo "Client URL: http://localhost:${CLIENT_PORT_FORWARD_PORT}"
echo "Port-forward PID: $CLIENT_PORT_FORWARD_PID (saved to $CLIENT_PF_PID_FILE)"
echo ""
echo "The client is now accessible at: http://localhost:${CLIENT_PORT_FORWARD_PORT}"
echo "The client will proxy GraphQL requests to the router"
echo ""
echo "Note: The port-forward is running in the background."
echo "      To stop it: kill \$(cat $CLIENT_PF_PID_FILE)"
echo ""
echo "Note: Make sure the router port-forward is also running."
echo "      Check with: ps aux | grep 'kubectl port-forward.*reference-architecture'"

