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

# Add Helm repositories for Prometheus and Grafana
echo ""
echo "Adding Helm repositories..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts 2>/dev/null || true
helm repo add grafana https://grafana.github.io/helm-charts 2>/dev/null || true
helm repo update

# Deploy Prometheus
echo ""
echo "Deploying Prometheus..."

# Check for existing Prometheus deployment and uninstall if present for clean setup
if helm list -n monitoring | grep -q "^prometheus[[:space:]]"; then
    echo "Found existing Prometheus deployment. Uninstalling for clean setup..."
    helm uninstall prometheus -n monitoring || true
    # Wait a moment for cleanup
    sleep 3
fi

# Deploy Prometheus with scrape config included from the start
PROMETHEUS_VALUES_FILE="deploy/prometheus/values.yaml"
if [ ! -f "${PROMETHEUS_VALUES_FILE}" ]; then
    echo "✗ Error: Prometheus values file not found at ${PROMETHEUS_VALUES_FILE}"
    exit 1
fi

echo "Deploying Prometheus with OpenTelemetry Collector scrape configuration..."
helm upgrade --install prometheus prometheus-community/prometheus \
    --namespace monitoring \
    -f "${PROMETHEUS_VALUES_FILE}" \
    --wait \
    --timeout 5m

if [ $? -eq 0 ]; then
    echo "✓ Prometheus deployed successfully with scrape configuration"
else
    echo "✗ Failed to deploy Prometheus"
    echo "Checking deployment status..."
    kubectl get pods -n monitoring -l app.kubernetes.io/name=prometheus || true
    exit 1
fi

# Wait for Prometheus pods to be ready
echo "Waiting for Prometheus pods to be ready..."
kubectl wait --for=condition=ready pod \
    -l app.kubernetes.io/name=prometheus \
    -n monitoring \
    --timeout=300s || true

# Ensure otel-collector scrape config is present in Prometheus ConfigMap
# This is needed because Helm's extraScrapeConfigs doesn't always work reliably
echo ""
echo "Ensuring otel-collector scrape config is present in Prometheus ConfigMap..."
CONFIGMAP="prometheus-server"
NAMESPACE="monitoring"

# Wait for ConfigMap to exist (it may take a moment after pod is ready)
for i in {1..10}; do
    if kubectl get configmap "$CONFIGMAP" -n "$NAMESPACE" &>/dev/null; then
        break
    fi
    echo "Waiting for ConfigMap to exist (attempt $i/10)..."
    sleep 2
done

if kubectl get configmap "$CONFIGMAP" -n "$NAMESPACE" &>/dev/null; then
    # Check if otel-collector scrape config already exists
    CURRENT_CONFIG=$(kubectl get configmap "$CONFIGMAP" -n "$NAMESPACE" -o jsonpath='{.data.prometheus\.yml}' 2>/dev/null || echo "")
    
    # Basic validation: if config is empty or missing key sections, restore from Helm
    if [ -z "$CURRENT_CONFIG" ] || ! echo "$CURRENT_CONFIG" | grep -q "^scrape_configs:"; then
        echo "⚠ Warning: Prometheus ConfigMap appears corrupted or empty. Restoring from Helm chart..."
        # Delete the ConfigMap so Helm can recreate it
        kubectl delete configmap "$CONFIGMAP" -n "$NAMESPACE" --ignore-not-found=true
        # Trigger Helm upgrade to recreate the ConfigMap with our values
        helm upgrade prometheus prometheus-community/prometheus \
            --namespace monitoring \
            -f "${PROMETHEUS_VALUES_FILE}" \
            --wait \
            --timeout 2m || true
        # Get the restored config
        sleep 3
        CURRENT_CONFIG=$(kubectl get configmap "$CONFIGMAP" -n "$NAMESPACE" -o jsonpath='{.data.prometheus\.yml}' 2>/dev/null || echo "")
        if [ -z "$CURRENT_CONFIG" ] || ! echo "$CURRENT_CONFIG" | grep -q "^scrape_configs:"; then
            echo "✗ Error: Failed to restore Prometheus ConfigMap"
            exit 1
        fi
        echo "✓ Prometheus ConfigMap restored"
    fi
    
    if echo "$CURRENT_CONFIG" | grep -q "job_name:.*otel-collector"; then
        echo "✓ otel-collector scrape config already present"
    else
        echo "Adding otel-collector scrape config to Prometheus ConfigMap..."
        
        # Create temp file with current config
        TEMP_CURRENT=$(mktemp)
        printf '%s\n' "$CURRENT_CONFIG" > "$TEMP_CURRENT"
        
        # Find where to insert (before rule_files: section, which is where scrape_configs ends)
        RULE_FILES_LINE=$(grep -n "^rule_files:" "$TEMP_CURRENT" | head -1 | cut -d: -f1)
        if [ -z "$RULE_FILES_LINE" ]; then
            # If no rule_files section, try to find alerting: as fallback
            ALERTING_LINE=$(grep -n "^alerting:" "$TEMP_CURRENT" | head -1 | cut -d: -f1)
            if [ -z "$ALERTING_LINE" ]; then
                # If no alerting section, append to end
                RULE_FILES_LINE=$(wc -l < "$TEMP_CURRENT" | tr -d ' ')
                RULE_FILES_LINE=$((RULE_FILES_LINE + 1))
            else
                RULE_FILES_LINE=$ALERTING_LINE
            fi
        fi
        
        # Insert after the last scrape_config entry (which ends at line before rule_files)
        INSERT_LINE=$((RULE_FILES_LINE - 1))
        
        # Create new config with otel-collector added using sed for precise insertion
        TEMP_NEW=$(mktemp)
        
        # Use sed to insert the new scrape config after INSERT_LINE
        # First, copy lines 1 to INSERT_LINE
        sed -n "1,${INSERT_LINE}p" "$TEMP_CURRENT" > "$TEMP_NEW"
        
        # Add the new scrape config with proper formatting
        # Ensure there's a newline before our config if the last line doesn't end with one
        LAST_CHAR=$(tail -c 1 "$TEMP_NEW" 2>/dev/null || echo "")
        if [ -n "$LAST_CHAR" ] && [ "$LAST_CHAR" != "$(printf '\n')" ]; then
            printf '\n' >> "$TEMP_NEW"
        fi
        
        # Insert the otel-collector scrape config
        cat >> "$TEMP_NEW" << 'EOF'
- job_name: 'otel-collector'
  static_configs:
    - targets: ['collector.monitoring.svc.cluster.local:9091']
EOF
        
        # Add the rest of the config (from rule_files: onwards)
        sed -n "${RULE_FILES_LINE},\$p" "$TEMP_CURRENT" >> "$TEMP_NEW"
        
        # Basic validation: check for required structure
        if ! grep -q "^scrape_configs:" "$TEMP_NEW"; then
            echo "✗ Error: scrape_configs section not found in new config"
            rm -f "$TEMP_CURRENT" "$TEMP_NEW"
            exit 1
        fi
        
        if ! grep -q "otel-collector" "$TEMP_NEW"; then
            echo "✗ Error: otel-collector config not found in new config"
            rm -f "$TEMP_CURRENT" "$TEMP_NEW"
            exit 1
        fi
        
        # Validate YAML structure: check that rule_files: still exists and scrape_configs is properly formatted
        if ! grep -q "^rule_files:" "$TEMP_NEW"; then
            echo "✗ Error: rule_files section missing in new config"
            rm -f "$TEMP_CURRENT" "$TEMP_NEW"
            exit 1
        fi
        
        # Count scrape_configs entries to ensure we have a valid list
        SCRAPE_COUNT=$(grep -c "^- job_name:" "$TEMP_NEW" || echo "0")
        if [ "$SCRAPE_COUNT" -lt 1 ]; then
            echo "✗ Error: No scrape_configs entries found"
            rm -f "$TEMP_CURRENT" "$TEMP_NEW"
            exit 1
        fi
        
        # Apply the updated config
        kubectl create configmap "$CONFIGMAP" \
            --from-file=prometheus.yml="$TEMP_NEW" \
            -n "$NAMESPACE" \
            --dry-run=client -o yaml | kubectl apply -f -
        
        echo "✓ otel-collector scrape config added to Prometheus ConfigMap"
        
        # Restart Prometheus to pick up the changes
        echo "Restarting Prometheus to pick up configuration changes..."
        kubectl rollout restart deployment/prometheus-server -n "$NAMESPACE" 2>/dev/null || \
        kubectl rollout restart statefulset/prometheus-server -n "$NAMESPACE" 2>/dev/null || true
        
        # Wait for restart to complete
        echo "Waiting for Prometheus to restart..."
        sleep 5
        kubectl wait --for=condition=ready pod \
            -l app.kubernetes.io/name=prometheus \
            -n monitoring \
            --timeout=120s || true
        
        # Clean up temp files
        rm -f "$TEMP_CURRENT" "$TEMP_NEW"
    fi
else
    echo "⚠ Warning: Prometheus ConfigMap not found, skipping scrape config update"
fi

# Get Prometheus service endpoint for collector
PROMETHEUS_SERVICE="prometheus-server"
# Check if the service exists (it might have a different name)
if ! kubectl get service "$PROMETHEUS_SERVICE" -n monitoring &> /dev/null; then
    # Try alternative service name
    PROMETHEUS_SERVICE=$(kubectl get svc -n monitoring -l app.kubernetes.io/name=prometheus -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "prometheus-server")
fi

echo "✓ Prometheus service: $PROMETHEUS_SERVICE"

# Create ConfigMap for GraphOS template dashboard before deploying Grafana
echo ""
echo "Creating ConfigMap for GraphOS template dashboard..."
if [ -f "deploy/grafana/graphos-template.json" ]; then
    # Create ConfigMap with the dashboard JSON
    # Grafana expects the key to match the dashboard filename pattern
    kubectl create configmap graphos-template-dashboard \
        --from-file=graphos-template.json=deploy/grafana/graphos-template.json \
        --namespace monitoring \
        --dry-run=client -o yaml | kubectl apply -f -
    
    # Label the ConfigMap so Grafana sidecar picks it up
    kubectl label configmap graphos-template-dashboard grafana_dashboard=1 -n monitoring --overwrite 2>/dev/null || \
    kubectl label configmap graphos-template-dashboard grafana_dashboard=1 -n monitoring 2>/dev/null || true
    
    echo "✓ GraphOS template dashboard ConfigMap created and labeled"
else
    echo "⚠ Warning: graphos-template.json not found at deploy/grafana/graphos-template.json"
    echo "  Dashboard will not be automatically provisioned"
fi

# Deploy Grafana
echo ""
echo "Deploying Grafana..."
helm upgrade --install grafana grafana/grafana \
    --namespace monitoring \
    -f deploy/grafana/values.yaml \
    --wait \
    --timeout 5m

if [ $? -eq 0 ]; then
    echo "✓ Grafana deployed successfully"
else
    echo "✗ Failed to deploy Grafana"
    exit 1
fi

# Wait for Grafana pods to be ready
echo "Waiting for Grafana pods to be ready..."
kubectl wait --for=condition=ready pod \
    -l app.kubernetes.io/name=grafana \
    -n monitoring \
    --timeout=300s || true

# Get Grafana admin password
GRAFANA_PASSWORD=$(kubectl get secret --namespace monitoring grafana -o jsonpath="{.data.admin-password}" | base64 --decode 2>/dev/null || echo "admin")
if [ "$GRAFANA_PASSWORD" = "admin" ]; then
    echo "Using default Grafana password: admin"
fi

# Configure Prometheus datasource in Grafana automatically
echo ""
echo "Configuring Prometheus datasource in Grafana..."

# Wait for Grafana to be ready
GRAFANA_POD=$(kubectl get pod -n monitoring -l app.kubernetes.io/name=grafana -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
if [ -n "$GRAFANA_POD" ]; then
    echo "Waiting for Grafana API to be ready..."
    for i in {1..30}; do
        if kubectl exec -n monitoring $GRAFANA_POD -- curl -s -o /dev/null -w "%{http_code}" http://localhost:3000/api/health 2>/dev/null | grep -q "200"; then
            echo "✓ Grafana API is ready"
            break
        fi
        sleep 2
    done
    
    # Get Prometheus service URL
    PROMETHEUS_URL="http://${PROMETHEUS_SERVICE}.monitoring.svc.cluster.local:80"
    
    # Create JSON file for datasource configuration
    cat > /tmp/prometheus-datasource.json <<EOF
{
  "name": "Prometheus",
  "type": "prometheus",
  "access": "proxy",
  "url": "${PROMETHEUS_URL}",
  "isDefault": true,
  "jsonData": {
    "timeInterval": "30s"
  }
}
EOF
    
    # Copy JSON file to Grafana pod
    kubectl cp /tmp/prometheus-datasource.json monitoring/$GRAFANA_POD:/tmp/prometheus-datasource.json 2>/dev/null || echo "Warning: Could not copy JSON file to pod"
    
    # Get datasource ID first (if it exists)
    DATASOURCE_ID=$(kubectl exec -n monitoring $GRAFANA_POD -- curl -s -u "admin:${GRAFANA_PASSWORD}" \
        http://localhost:3000/api/datasources/name/Prometheus 2>/dev/null | \
        grep -o '"id":[0-9]*' | head -1 | cut -d':' -f2 || echo "")
    
    if [ -n "$DATASOURCE_ID" ]; then
        # Update existing datasource
        echo "Updating existing Prometheus datasource (ID: $DATASOURCE_ID)..."
        UPDATE_RESULT=$(kubectl exec -n monitoring $GRAFANA_POD -- curl -s -X PUT \
            -u "admin:${GRAFANA_PASSWORD}" \
            -H "Content-Type: application/json" \
            -d @/tmp/prometheus-datasource.json \
            http://localhost:3000/api/datasources/${DATASOURCE_ID} 2>/dev/null || echo "")
    else
        # Create new datasource
        echo "Creating Prometheus datasource..."
        UPDATE_RESULT=$(kubectl exec -n monitoring $GRAFANA_POD -- curl -s -X POST \
            -u "admin:${GRAFANA_PASSWORD}" \
            -H "Content-Type: application/json" \
            -d @/tmp/prometheus-datasource.json \
            http://localhost:3000/api/datasources 2>/dev/null || echo "")
    fi
    
    # Clean up temp file
    rm -f /tmp/prometheus-datasource.json
    
    # Check if configuration was successful
    if echo "$UPDATE_RESULT" | grep -q '"message":"Datasource added"' || echo "$UPDATE_RESULT" | grep -q '"id"'; then
        echo "✓ Prometheus datasource configured successfully"
    elif [ -n "$UPDATE_RESULT" ]; then
        echo "✓ Prometheus datasource configuration attempted"
        echo "  (You may need to verify in Grafana UI: Configuration → Data Sources)"
    else
        echo "⚠ Could not configure Prometheus datasource via API"
        echo "  Configure manually: Configuration → Data Sources → Prometheus"
        echo "  URL: ${PROMETHEUS_URL}"
    fi
else
    echo "⚠ Could not find Grafana pod to configure datasource"
    echo "  Configure manually: Configuration → Data Sources → Prometheus"
        echo "  URL: http://${PROMETHEUS_SERVICE}.monitoring.svc.cluster.local:80"
fi

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

# Set up port-forwarding for Grafana
GRAFANA_SERVICE="grafana"
GRAFANA_PORT_FORWARD_PORT=3002
GRAFANA_PF_PID_FILE=".grafana-port-forward.pid"

# Check if Grafana service exists
echo ""
echo "Setting up Grafana port-forward..."
if ! kubectl get service "$GRAFANA_SERVICE" -n monitoring &> /dev/null; then
    echo "Warning: Grafana service '$GRAFANA_SERVICE' not found in namespace 'monitoring'"
    echo "Skipping Grafana port-forward setup"
    echo "  You can manually start it with: kubectl port-forward service/grafana -n monitoring ${GRAFANA_PORT_FORWARD_PORT}:80"
else
    echo "Found Grafana service, setting up port-forward..."
    # Clean up existing PID file and any stale process
    if [ -f "$GRAFANA_PF_PID_FILE" ]; then
        OLD_PID=$(cat "$GRAFANA_PF_PID_FILE" 2>/dev/null | head -n 1 | tr -d '[:space:]' || echo "")
        if [ -n "$OLD_PID" ] && kill -0 "$OLD_PID" 2>/dev/null; then
            echo "Found existing Grafana port-forward process (PID: $OLD_PID). Stopping it..."
            kill "$OLD_PID" 2>/dev/null || true
            sleep 2
        fi
        rm -f "$GRAFANA_PF_PID_FILE"
    fi

    # Check if port-forward is already running on this port
    if lsof -ti:${GRAFANA_PORT_FORWARD_PORT} &> /dev/null; then
        echo "Port ${GRAFANA_PORT_FORWARD_PORT} is already in use. Checking if it's a kubectl port-forward..."
        EXISTING_PF=$(ps aux | grep "kubectl port-forward.*${GRAFANA_SERVICE}.*${GRAFANA_PORT_FORWARD_PORT}" | grep -v grep | awk '{print $2}' || echo "")
        if [ -n "$EXISTING_PF" ]; then
            echo "Found existing port-forward (PID: $EXISTING_PF). Stopping it..."
            kill $EXISTING_PF 2>/dev/null || true
            sleep 2
        else
            echo "Warning: Port ${GRAFANA_PORT_FORWARD_PORT} is in use by another process"
            echo "Please free the port or use a different port"
        fi
    fi

    # Get the Grafana service port (usually 80, not 3000)
    GRAFANA_SERVICE_PORT=$(kubectl get svc $GRAFANA_SERVICE -n monitoring -o jsonpath='{.spec.ports[0].port}' 2>/dev/null || echo "80")
    if [ -z "$GRAFANA_SERVICE_PORT" ] || [ "$GRAFANA_SERVICE_PORT" = "" ]; then
        GRAFANA_SERVICE_PORT="80"
    fi
    
    # Start port-forwarding in the background
    echo ""
    echo "Starting port-forward for Grafana service..."
    echo "  Mapping localhost:${GRAFANA_PORT_FORWARD_PORT} -> grafana:${GRAFANA_SERVICE_PORT}"
    
    # Start port-forward in background using nohup (same as Collector)
    nohup kubectl port-forward service/$GRAFANA_SERVICE -n monitoring ${GRAFANA_PORT_FORWARD_PORT}:${GRAFANA_SERVICE_PORT} > /tmp/grafana-port-forward.log 2>&1 &
    GRAFANA_PORT_FORWARD_PID=$!
    
    # Disown the process so it continues after script exits
    disown $GRAFANA_PORT_FORWARD_PID 2>/dev/null || true

    # Wait a moment for port-forward to establish
    sleep 3

    # Verify port-forward is running
    if ! kill -0 $GRAFANA_PORT_FORWARD_PID 2>/dev/null; then
        echo "✗ Error: Grafana port-forward failed to start (PID: $GRAFANA_PORT_FORWARD_PID)"
        echo "  Check logs: cat /tmp/grafana-port-forward.log"
        echo "  You can manually start it with:"
        echo "  kubectl port-forward service/grafana -n monitoring ${GRAFANA_PORT_FORWARD_PORT}:${GRAFANA_SERVICE_PORT}"
    else
        # Test if the port is accessible
        if ! lsof -ti:${GRAFANA_PORT_FORWARD_PORT} &> /dev/null; then
            echo "Warning: Grafana port-forward started but port ${GRAFANA_PORT_FORWARD_PORT} is not accessible"
            echo "Port-forward PID: $GRAFANA_PORT_FORWARD_PID"
            echo "  Check if the port-forward is working: kubectl port-forward service/grafana -n monitoring ${GRAFANA_PORT_FORWARD_PORT}:${GRAFANA_SERVICE_PORT}"
            echo "  Check logs: cat /tmp/grafana-port-forward.log"
        else
            echo "✓ Grafana port-forward is running (PID: $GRAFANA_PORT_FORWARD_PID)"
            echo "  Grafana is accessible at: http://localhost:${GRAFANA_PORT_FORWARD_PORT}"
            echo "  Port-forward PID saved to: $GRAFANA_PF_PID_FILE"
            echo ""
            echo "Note: The port-forward is running in the background."
            echo "      To stop it: kill \$(cat $GRAFANA_PF_PID_FILE)"
        fi
    fi

    # Save PID to a file for cleanup later
    echo "$GRAFANA_PORT_FORWARD_PID" > "$GRAFANA_PF_PID_FILE"
fi

echo ""
echo "✓ Telemetry stack deployment complete!"
echo ""
echo "Services are now available at:"
echo "  Zipkin UI: http://zipkin.monitoring.svc.cluster.local:9411"
echo "  OTEL Collector (HTTP): http://collector.monitoring.svc.cluster.local:4318"
echo "  OTEL Collector (gRPC): http://collector.monitoring.svc.cluster.local:4317"
echo "  Prometheus: http://${PROMETHEUS_SERVICE}.monitoring.svc.cluster.local:80"
echo "  Grafana: http://grafana.monitoring.svc.cluster.local:3000"
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
echo "Metrics flow: Router/Subgraphs → OTEL Collector → Prometheus → Grafana"
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

# Display Grafana access information
if [ -f "$GRAFANA_PF_PID_FILE" ]; then
    GRAFANA_PID=$(cat "$GRAFANA_PF_PID_FILE" 2>/dev/null | head -n 1 | tr -d '[:space:]' || echo "")
    if [ -n "$GRAFANA_PID" ] && kill -0 "$GRAFANA_PID" 2>/dev/null; then
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "📊 How to View Metrics in Grafana:"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        echo "1. Open Grafana UI in your browser:"
        echo "   → http://localhost:${GRAFANA_PORT_FORWARD_PORT}"
        echo ""
        echo "2. Login credentials:"
        echo "   Username: admin"
        echo "   Password: $GRAFANA_PASSWORD"
        echo "   (Get password with: kubectl get secret --namespace monitoring grafana -o jsonpath=\"{.data.admin-password}\" | base64 --decode)"
        echo ""
        echo "3. Prometheus datasource:"
        echo "   ✓ Prometheus datasource should be automatically configured"
        echo "   If you need to configure it manually:"
        echo "   • Go to: Configuration → Data Sources → Prometheus"
        echo "   • URL: http://${PROMETHEUS_SERVICE}.monitoring.svc.cluster.local:80"
        echo ""
        echo "4. Metrics are automatically collected from:"
        echo "   • Apollo Router (via OTLP metrics exporter)"
        echo "   • All subgraphs (via OpenTelemetry SDK)"
        echo ""
        echo "5. Create dashboards to visualize:"
        echo "   • Request rates and latencies"
        echo "   • Error rates"
        echo "   • Resource utilization"
        echo "   • Custom business metrics"
        echo ""
        echo "Note: The port-forward is running in the background."
        echo "      To stop it: kill \$(cat $GRAFANA_PF_PID_FILE)"
        echo "      To restart it: kubectl port-forward service/grafana -n monitoring ${GRAFANA_PORT_FORWARD_PORT}:80"
        echo ""
    else
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "📊 How to View Metrics in Grafana:"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        echo "1. Start port-forwarding for Grafana:"
        echo "   kubectl port-forward -n monitoring svc/grafana 3002:80"
        echo ""
        echo "2. Open Grafana UI in your browser:"
        echo "   → http://localhost:3002"
        echo ""
        echo "3. Login credentials:"
        echo "   Username: admin"
        echo "   Password: $GRAFANA_PASSWORD"
        echo "   (Get password with: kubectl get secret --namespace monitoring grafana -o jsonpath=\"{.data.admin-password}\" | base64 --decode)"
        echo ""
        echo "4. Prometheus datasource:"
        echo "   To configure Prometheus datasource manually:"
        echo "   • Go to: Configuration → Data Sources → Prometheus"
        echo "   • URL: http://${PROMETHEUS_SERVICE}.monitoring.svc.cluster.local:80"
        echo ""
        echo "5. Metrics are automatically collected from:"
        echo "   • Apollo Router (via OTLP metrics exporter)"
        echo "   • All subgraphs (via OpenTelemetry SDK)"
        echo ""
        echo "6. Create dashboards to visualize:"
        echo "   • Request rates and latencies"
        echo "   • Error rates"
        echo "   • Resource utilization"
        echo "   • Custom business metrics"
        echo ""
    fi
else
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📊 How to View Metrics in Grafana:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "1. Start port-forwarding for Grafana:"
    echo "   kubectl port-forward -n monitoring svc/grafana 3002:80"
    echo ""
    echo "2. Open Grafana UI in your browser:"
    echo "   → http://localhost:3001"
    echo ""
    echo "3. Login credentials:"
    echo "   Username: admin"
    echo "   Password: $GRAFANA_PASSWORD"
    echo "   (Get password with: kubectl get secret --namespace monitoring grafana -o jsonpath=\"{.data.admin-password}\" | base64 --decode)"
    echo ""
    echo "4. Prometheus datasource:"
    echo "   To configure Prometheus datasource manually:"
    echo "   • Go to: Configuration → Data Sources → Prometheus"
    echo "   • URL: http://${PROMETHEUS_SERVICE}.monitoring.svc.cluster.local:9090"
    echo ""
    echo "5. Metrics are automatically collected from:"
    echo "   • Apollo Router (via OTLP metrics exporter)"
    echo "   • All subgraphs (via OpenTelemetry SDK)"
    echo ""
    echo "6. Create dashboards to visualize:"
    echo "   • Request rates and latencies"
    echo "   • Error rates"
    echo "   • Resource utilization"
    echo "   • Custom business metrics"
    echo ""
fi

