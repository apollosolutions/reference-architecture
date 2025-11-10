#!/bin/bash
set -euo pipefail

# Script 07: Deploy Operator Resources
# This script deploys SupergraphSchema and Supergraph CRDs
# Note: The coprocessor (script 06) must be deployed first as the router requires it

echo "=== Step 07: Deploying Operator Resources ==="

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

if [[ -z "${APOLLO_GRAPH_ID:-}" ]]; then
    echo "Error: APOLLO_GRAPH_ID is not set"
    echo "Please run 02-setup-apollo-graph.sh first"
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

# Ensure apollo namespace exists
kubectl create namespace apollo --dry-run=client -o yaml | kubectl apply -f -

# Resource name based on environment
RESOURCE_NAME="reference-architecture-${ENVIRONMENT}"

# Create router configuration ConfigMap
echo "Creating router configuration ConfigMap..."
kubectl create configmap router-config \
    --from-file=router.yaml=deploy/operator-resources/router-config.yaml \
    -n apollo \
    --dry-run=client -o yaml | kubectl apply -f -

echo "Router configuration ConfigMap created"

# Deploy SupergraphSchema
echo "Deploying SupergraphSchema..."
cat <<EOF | kubectl apply -f -
apiVersion: apollographql.com/v1alpha2
kind: SupergraphSchema
metadata:
  name: ${RESOURCE_NAME}
  namespace: apollo
spec:
  graphRef: ${APOLLO_GRAPH_ID}@${ENVIRONMENT}
  selectors:
    - matchExpressions:
        - key: apollo.io/subgraph
          operator: Exists
  partial: false
EOF

echo "SupergraphSchema deployed"

# Wait a moment for schema to be composed
echo "Waiting for schema composition..."
sleep 5

# Deploy Supergraph with ConfigMap-mounted router configuration
# The router configuration is loaded from the ConfigMap and mounted as a volume
# The router will use the --config flag to reference the mounted file
echo "Deploying Supergraph..."
cat <<EOF | kubectl apply -f -
apiVersion: apollographql.com/v1alpha2
kind: Supergraph
metadata:
  name: ${RESOURCE_NAME}
  namespace: apollo
spec:
  replicas: 3
  podTemplate:
    routerVersion: 2.7.0
    resources:
      requests:
        cpu: 100m
        memory: 256Mi
  schema:
    resource:
      name: ${RESOURCE_NAME}
      namespace: apollo
EOF

echo "Supergraph deployed"

# Wait for router deployment to be created
echo "Waiting for router deployment to be created..."
DEPLOYMENT_NAME="${RESOURCE_NAME}"
for i in {1..60}; do
    if kubectl get deployment ${DEPLOYMENT_NAME} -n apollo &>/dev/null; then
        echo "Router deployment found"
        break
    fi
    echo "  Waiting for deployment... ($i/60)"
    sleep 2
done

if ! kubectl get deployment ${DEPLOYMENT_NAME} -n apollo &>/dev/null; then
    echo "Error: Router deployment not found after waiting"
    echo "Please check the Supergraph status:"
    echo "  kubectl get supergraph ${RESOURCE_NAME} -n apollo"
    exit 1
fi

# Patch the router deployment to mount the ConfigMap and use it
echo "Patching router deployment to use ConfigMap..."

# Check if volume already exists, if not add it
if ! kubectl get deployment ${DEPLOYMENT_NAME} -n apollo -o jsonpath='{.spec.template.spec.volumes[*].name}' | grep -q "router-config"; then
    kubectl patch deployment ${DEPLOYMENT_NAME} -n apollo --type='json' -p='[
        {
            "op": "add",
            "path": "/spec/template/spec/volumes/-",
            "value": {
                "name": "router-config",
                "configMap": {
                    "name": "router-config"
                }
            }
        }
    ]'
    echo "  Added router-config volume"
else
    echo "  Volume already exists"
fi

# Check if volumeMount already exists, if not add it
if ! kubectl get deployment ${DEPLOYMENT_NAME} -n apollo -o jsonpath='{.spec.template.spec.containers[0].volumeMounts[*].name}' | grep -q "router-config"; then
    kubectl patch deployment ${DEPLOYMENT_NAME} -n apollo --type='json' -p='[
        {
            "op": "add",
            "path": "/spec/template/spec/containers/0/volumeMounts/-",
            "value": {
                "name": "router-config",
                "mountPath": "/etc/router",
                "readOnly": true
            }
        }
    ]'
    echo "  Added router-config volumeMount"
else
    echo "  VolumeMount already exists"
fi

# Check if --config args already exist, if not add them
CURRENT_ARGS=$(kubectl get deployment ${DEPLOYMENT_NAME} -n apollo -o jsonpath='{.spec.template.spec.containers[0].args[*]}' || echo "")
if [[ ! "$CURRENT_ARGS" =~ "--config" ]]; then
    kubectl patch deployment ${DEPLOYMENT_NAME} -n apollo --type='json' -p='[
        {
            "op": "add",
            "path": "/spec/template/spec/containers/0/args/-",
            "value": "--config"
        },
        {
            "op": "add",
            "path": "/spec/template/spec/containers/0/args/-",
            "value": "/etc/router/router.yaml"
        }
    ]'
    echo "  Added --config arguments"
else
    echo "  --config arguments already exist"
fi

echo "Router deployment patched"

# Wait for rollout to complete
echo "Waiting for router rollout to complete..."
kubectl rollout status deployment/${DEPLOYMENT_NAME} -n apollo --timeout=300s || true

# Wait for router to be ready
echo "Waiting for router to be ready..."
kubectl wait --for=condition=ready --timeout=300s supergraph/${RESOURCE_NAME} -n apollo || true

echo ""
echo "✓ Operator resources deployed!"
echo ""
echo "Router configuration has been applied via ConfigMap:"
echo "  ConfigMap: router-config (contains router.yaml)"
echo "  Mounted at: /etc/router/router.yaml"
echo "  Router args: --config /etc/router/router.yaml"
echo ""
echo "Monitor router status with:"
echo "  kubectl get supergraphs -n apollo"
echo "  kubectl get pods -n apollo"
echo "  kubectl logs -n apollo deployment/${DEPLOYMENT_NAME}"
echo ""
echo "Next step: Run 08-deploy-ingress.sh to setup external access"

