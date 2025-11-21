#!/bin/bash
set -euo pipefail

# Script 10: Deploy Telemetry Stack
# This script deploys Zipkin and OpenTelemetry Collector for distributed tracing
# Both services are deployed in the monitoring namespace

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

echo ""
echo "✓ Telemetry stack deployment complete!"
echo ""
echo "Services are now available at:"
echo "  Zipkin UI: http://zipkin.monitoring.svc.cluster.local:9411"
echo "  OTEL Collector (HTTP): http://collector.monitoring.svc.cluster.local:4318"
echo "  OTEL Collector (gRPC): http://collector.monitoring.svc.cluster.local:4317"
echo ""
echo "To access Zipkin UI from your local machine:"
echo "  kubectl port-forward -n monitoring svc/zipkin 9411:9411"
echo "  Then open http://localhost:9411 in your browser"
echo ""
echo "Telemetry is now configured for:"
echo "  - All subgraphs (via OTEL_HTTP_ENDPOINT)"
echo "  - Apollo Router (via router-config.yaml)"
echo ""
echo "Traces flow: Subgraphs/Router → OTEL Collector → Zipkin"

