#!/bin/bash
set -euo pipefail

# Script 10: Deploy Telemetry Stack
# This script deploys Zipkin and OpenTelemetry Collector for distributed tracing
# Both services are deployed in the monitoring namespace

# Ensure script is run from repository root
if [ ! -d "scripts/minikube" ] || [ ! -d "subgraphs" ] || [ ! -d "deploy" ]; then
    echo "Error: This script must be run from the repository root directory"
    echo "Please run: ./scripts/minikube/10-deploy-telemetry.sh"
    exit 1
fi

echo "=== Step 10: Deploying Telemetry Stack ==="

# Load environment variables from .env if it exists
if [ -f .env ]; then
    echo "Loading environment variables from .env..."
    source .env
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

# Create monitoring namespace
echo "Creating monitoring namespace..."
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -

# Deploy Zipkin
echo ""
echo "Deploying Zipkin..."
helm upgrade --install zipkin deploy/zipkin \
    --namespace monitoring \
    --wait \
    --timeout 5m

if [ $? -eq 0 ]; then
    echo "✓ Zipkin deployed successfully"
else
    echo "✗ Failed to deploy Zipkin"
    exit 1
fi

# Wait for Zipkin pods to be ready
echo "Waiting for Zipkin pods to be ready..."
kubectl wait --for=condition=ready pod \
    -l app.kubernetes.io/name=zipkin \
    -n monitoring \
    --timeout=300s || true

# Deploy OTEL Collector
echo ""
echo "Deploying OpenTelemetry Collector..."
helm upgrade --install collector deploy/collector \
    --namespace monitoring \
    --wait \
    --timeout 5m

if [ $? -eq 0 ]; then
    echo "✓ OpenTelemetry Collector deployed successfully"
else
    echo "✗ Failed to deploy OpenTelemetry Collector"
    exit 1
fi

# Wait for Collector pods to be ready
echo "Waiting for Collector pods to be ready..."
kubectl wait --for=condition=ready pod \
    -l app.kubernetes.io/name=collector \
    -n monitoring \
    --timeout=300s || true

# Check services
echo ""
echo "Checking services..."
kubectl get svc -n monitoring

# Set up port-forwarding for Zipkin
ZIPKIN_SERVICE="zipkin"
ZIPKIN_PORT_FORWARD_PORT=9411
ZIPKIN_PF_PID_FILE=".zipkin-port-forward.pid"

# Check if Zipkin service exists
if ! kubectl get service "$ZIPKIN_SERVICE" -n monitoring &> /dev/null; then
    echo "Warning: Zipkin service '$ZIPKIN_SERVICE' not found in namespace 'monitoring'"
    echo "Skipping port-forward setup"
else
    # Clean up existing PID file and any stale process
    if [ -f "$ZIPKIN_PF_PID_FILE" ]; then
        OLD_PID=$(cat "$ZIPKIN_PF_PID_FILE" 2>/dev/null | head -n 1 | tr -d '[:space:]' || echo "")
        if [ -n "$OLD_PID" ] && kill -0 "$OLD_PID" 2>/dev/null; then
            echo "Found existing Zipkin port-forward process (PID: $OLD_PID). Stopping it..."
            kill "$OLD_PID" 2>/dev/null || true
            sleep 2
        fi
        rm -f "$ZIPKIN_PF_PID_FILE"
    fi

    # Check if port-forward is already running on this port
    if lsof -ti:${ZIPKIN_PORT_FORWARD_PORT} &> /dev/null; then
        echo "Port ${ZIPKIN_PORT_FORWARD_PORT} is already in use. Checking if it's a kubectl port-forward..."
        # Try to find kubectl port-forward processes for this service
        EXISTING_PF=$(ps aux | grep "kubectl port-forward.*${ZIPKIN_SERVICE}.*${ZIPKIN_PORT_FORWARD_PORT}" | grep -v grep | awk '{print $2}' || echo "")
        if [ -n "$EXISTING_PF" ]; then
            echo "Found existing port-forward (PID: $EXISTING_PF). Stopping it..."
            kill $EXISTING_PF 2>/dev/null || true
            sleep 2
        else
            echo "Warning: Port ${ZIPKIN_PORT_FORWARD_PORT} is in use by another process"
            echo "Please free the port or use a different port"
        fi
    fi

    # Start port-forwarding in the background
    echo ""
    echo "Starting port-forward for Zipkin service..."
    nohup kubectl port-forward service/$ZIPKIN_SERVICE -n monitoring ${ZIPKIN_PORT_FORWARD_PORT}:9411 > /dev/null 2>&1 &
    ZIPKIN_PORT_FORWARD_PID=$!
    # Disown the process so it continues after script exits
    disown $ZIPKIN_PORT_FORWARD_PID 2>/dev/null || true

    # Wait a moment for port-forward to establish
    sleep 3

    # Verify port-forward is running
    if ! kill -0 $ZIPKIN_PORT_FORWARD_PID 2>/dev/null; then
        echo "Warning: Zipkin port-forward failed to start"
    else
        # Test if the port is accessible
        if ! lsof -ti:${ZIPKIN_PORT_FORWARD_PORT} &> /dev/null; then
            echo "Warning: Zipkin port-forward started but port ${ZIPKIN_PORT_FORWARD_PORT} is not accessible"
            echo "Port-forward PID: $ZIPKIN_PORT_FORWARD_PID"
        else
            echo "✓ Zipkin port-forward is running (PID: $ZIPKIN_PORT_FORWARD_PID)"
        fi
    fi

    # Save PID to a file for cleanup later
    echo "$ZIPKIN_PORT_FORWARD_PID" > "$ZIPKIN_PF_PID_FILE"
fi

# Set up port-forwarding for Collector (needed for browser tracing)
COLLECTOR_SERVICE="collector"
COLLECTOR_PORT_FORWARD_PORT=4318
COLLECTOR_PF_PID_FILE=".collector-port-forward.pid"

# Check if Collector service exists
if ! kubectl get service "$COLLECTOR_SERVICE" -n monitoring &> /dev/null; then
    echo "Warning: Collector service '$COLLECTOR_SERVICE' not found in namespace 'monitoring'"
    echo "Skipping collector port-forward setup"
else
    # Clean up existing PID file and any stale process
    if [ -f "$COLLECTOR_PF_PID_FILE" ]; then
        OLD_PID=$(cat "$COLLECTOR_PF_PID_FILE" 2>/dev/null | head -n 1 | tr -d '[:space:]' || echo "")
        if [ -n "$OLD_PID" ] && kill -0 "$OLD_PID" 2>/dev/null; then
            echo "Found existing Collector port-forward process (PID: $OLD_PID). Stopping it..."
            kill "$OLD_PID" 2>/dev/null || true
            sleep 2
        fi
        rm -f "$COLLECTOR_PF_PID_FILE"
    fi

    # Check if port-forward is already running on this port
    if lsof -ti:${COLLECTOR_PORT_FORWARD_PORT} &> /dev/null; then
        echo "Port ${COLLECTOR_PORT_FORWARD_PORT} is already in use. Checking if it's a kubectl port-forward..."
        EXISTING_PF=$(ps aux | grep "kubectl port-forward.*${COLLECTOR_SERVICE}.*${COLLECTOR_PORT_FORWARD_PORT}" | grep -v grep | awk '{print $2}' || echo "")
        if [ -n "$EXISTING_PF" ]; then
            echo "Found existing port-forward (PID: $EXISTING_PF). Stopping it..."
            kill $EXISTING_PF 2>/dev/null || true
            sleep 2
        else
            echo "Warning: Port ${COLLECTOR_PORT_FORWARD_PORT} is in use by another process"
            echo "Please free the port or use a different port"
        fi
    fi

    # Start port-forwarding in the background
    echo ""
    echo "Starting port-forward for Collector service..."
    echo "  Mapping localhost:${COLLECTOR_PORT_FORWARD_PORT} -> collector:4318"
    nohup kubectl port-forward service/$COLLECTOR_SERVICE -n monitoring ${COLLECTOR_PORT_FORWARD_PORT}:4318 > /dev/null 2>&1 &
    COLLECTOR_PORT_FORWARD_PID=$!
    # Disown the process so it continues after script exits
    disown $COLLECTOR_PORT_FORWARD_PID 2>/dev/null || true

    # Wait a moment for port-forward to establish
    sleep 3

    # Verify port-forward is running
    if ! kill -0 $COLLECTOR_PORT_FORWARD_PID 2>/dev/null; then
        echo "✗ Error: Collector port-forward failed to start"
        echo "  You can manually start it with:"
        echo "  kubectl port-forward service/collector -n monitoring ${COLLECTOR_PORT_FORWARD_PORT}:4318"
    else
        # Test if the port is accessible
        if ! lsof -ti:${COLLECTOR_PORT_FORWARD_PORT} &> /dev/null; then
            echo "Warning: Collector port-forward started but port ${COLLECTOR_PORT_FORWARD_PORT} is not accessible"
            echo "Port-forward PID: $COLLECTOR_PORT_FORWARD_PID"
            echo "  Check if the port-forward is working: kubectl port-forward service/collector -n monitoring ${COLLECTOR_PORT_FORWARD_PORT}:4318"
        else
            echo "✓ Collector port-forward is running (PID: $COLLECTOR_PORT_FORWARD_PID)"
            echo "  Collector is accessible at: http://localhost:${COLLECTOR_PORT_FORWARD_PORT}"
        fi
    fi

    # Save PID to a file for cleanup later
    echo "$COLLECTOR_PORT_FORWARD_PID" > "$COLLECTOR_PF_PID_FILE"
fi

echo ""
echo "✓ Telemetry stack deployment complete!"
echo ""
echo "Services are now available at:"
echo "  Zipkin UI: http://zipkin.monitoring.svc.cluster.local:9411"
echo "  OTEL Collector (HTTP): http://collector.monitoring.svc.cluster.local:4318"
echo "  OTEL Collector (gRPC): http://collector.monitoring.svc.cluster.local:4317"
echo ""
if [ -f "$ZIPKIN_PF_PID_FILE" ]; then
    ZIPKIN_PID=$(cat "$ZIPKIN_PF_PID_FILE" 2>/dev/null | head -n 1 | tr -d '[:space:]' || echo "")
    if [ -n "$ZIPKIN_PID" ] && kill -0 "$ZIPKIN_PID" 2>/dev/null; then
        echo "✓ Zipkin UI is accessible at: http://localhost:${ZIPKIN_PORT_FORWARD_PORT}"
        echo "  Port-forward PID: $ZIPKIN_PID (saved to $ZIPKIN_PF_PID_FILE)"
        echo ""
        echo "Note: The port-forward is running in the background."
        echo "      To stop it: kill \$(cat $ZIPKIN_PF_PID_FILE)"
        echo ""
    fi
fi
echo "Telemetry is now configured for:"
echo "  - All subgraphs (via OTEL_HTTP_ENDPOINT)"
echo "  - Apollo Router (via router-config.yaml)"
echo "  - Browser client (via OpenTelemetry browser SDK)"
echo ""
echo "Traces flow: Browser Client → Subgraphs/Router → OTEL Collector → Zipkin"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 How to View Traces:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
if [ -f "$ZIPKIN_PF_PID_FILE" ]; then
    ZIPKIN_PID=$(cat "$ZIPKIN_PF_PID_FILE" 2>/dev/null | head -n 1 | tr -d '[:space:]' || echo "")
    if [ -n "$ZIPKIN_PID" ] && kill -0 "$ZIPKIN_PID" 2>/dev/null; then
        echo "1. Open Zipkin UI in your browser:"
        echo "   → http://localhost:${ZIPKIN_PORT_FORWARD_PORT}"
        echo ""
        echo "2. Generate some traffic to see traces:"
        echo "   • Make GraphQL requests via the client: http://localhost:3000"
        echo "   • Or directly to the router: http://localhost:4000/"
        echo ""
        echo "3. In Zipkin UI:"
        echo "   • Click 'Run Query' to see recent traces"
        echo "   • Filter by service name (e.g., 'reference-architecture-dev' for router)"
        echo "   • Click a trace to see the full span tree with timing details"
        echo ""
    else
        echo "1. Start port-forwarding for Zipkin:"
        echo "   kubectl port-forward -n monitoring svc/zipkin 9411:9411"
        echo ""
        echo "2. Open Zipkin UI in your browser:"
        echo "   → http://localhost:9411"
        echo ""
        echo "3. Generate some traffic to see traces:"
        echo "   • Make GraphQL requests via the client: http://localhost:3000"
        echo "   • Or directly to the router: http://localhost:4000/"
        echo ""
        echo "4. In Zipkin UI:"
        echo "   • Click 'Run Query' to see recent traces"
        echo "   • Filter by service name (e.g., 'reference-architecture-dev' for router)"
        echo "   • Click a trace to see the full span tree with timing details"
        echo ""
    fi
else
    echo "1. Start port-forwarding for Zipkin:"
    echo "   kubectl port-forward -n monitoring svc/zipkin 9411:9411"
    echo ""
    echo "2. Open Zipkin UI in your browser:"
    echo "   → http://localhost:9411"
    echo ""
    echo "3. Generate some traffic to see traces:"
    echo "   • Make GraphQL requests via the client: http://localhost:3000"
    echo "   • Or directly to the router: http://localhost:4000/"
    echo ""
    echo "4. In Zipkin UI:"
    echo "   • Click 'Run Query' to see recent traces"
    echo "   • Filter by service name (e.g., 'reference-architecture-dev' for router)"
    echo "   • Click a trace to see the full span tree with timing details"
    echo ""
fi
echo "💡 Tip: If you don't see traces, ensure the router and subgraphs are running"
echo "   and making requests. Traces will appear after GraphQL queries are executed."
echo ""
if [ -f "$COLLECTOR_PF_PID_FILE" ]; then
    COLLECTOR_PID=$(cat "$COLLECTOR_PF_PID_FILE" 2>/dev/null | head -n 1 | tr -d '[:space:]' || echo "")
    if [ -n "$COLLECTOR_PID" ] && kill -0 "$COLLECTOR_PID" 2>/dev/null; then
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "🌐 Browser Tracing Setup:"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        echo "✓ Collector port-forward is running on port ${COLLECTOR_PORT_FORWARD_PORT}"
        echo "  The browser client will automatically send traces to:"
        echo "  → http://localhost:${COLLECTOR_PORT_FORWARD_PORT}/v1/traces"
        echo ""
        echo "The client is configured to use this endpoint by default."
        echo "To use a different endpoint, set VITE_OTEL_COLLECTOR_URL when building the client."
        echo ""
        echo "Note: The port-forward is running in the background."
        echo "      To stop it: kill \$(cat $COLLECTOR_PF_PID_FILE)"
        echo "      To restart it: kubectl port-forward service/collector -n monitoring ${COLLECTOR_PORT_FORWARD_PORT}:4318"
        echo ""
    else
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "🌐 Browser Tracing Setup:"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        echo "⚠ Collector port-forward is not running"
        echo "  To start it manually, run:"
        echo "  kubectl port-forward service/collector -n monitoring ${COLLECTOR_PORT_FORWARD_PORT}:4318"
        echo ""
        echo "  Or re-run this script to set it up automatically."
        echo ""
    fi
fi

