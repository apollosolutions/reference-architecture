#!/bin/bash
set -euo pipefail

# Script 05: Deploy Subgraphs
# This script deploys all subgraphs using Helm and creates Subgraph CRDs with inline SDL

echo "=== Step 05: Deploying Subgraphs ==="

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

# Check if local registry is enabled and get registry URL
REGISTRY_URL=""
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
    
    # Use ClusterIP for both Helm deployments and Subgraph CRDs (operator) - HTTP
    REGISTRY_URL="${REGISTRY_CLUSTER_IP}:${REGISTRY_PORT}"
    REGISTRY_URL_FOR_OPERATOR="${REGISTRY_CLUSTER_IP}:${REGISTRY_PORT}"
    
    echo "Local registry enabled (HTTP)."
    echo "  - Using ClusterIP (${REGISTRY_URL}) for Helm deployments (kubelet) and Subgraph CRDs (operator)"
    
    # Read image tag from file (created by script 04)
    if [ ! -f ".image-tag" ]; then
        echo "Error: .image-tag file not found"
        echo "Please run 04-build-images.sh first when using registry"
        exit 1
    fi
    
    # Read only the first line and remove any whitespace/newlines
    IMAGE_TAG=$(head -n 1 .image-tag | tr -d '[:space:]')
    
    # Validate tag format (should be alphanumeric, 12 chars expected)
    if [ -z "$IMAGE_TAG" ] || [ ${#IMAGE_TAG} -lt 8 ]; then
        echo "Error: Invalid image tag in .image-tag: '${IMAGE_TAG}'"
        echo "Tag must be at least 8 characters. Please run 04-build-images.sh again"
        exit 1
    fi
    
    echo "Using image tag from .image-tag: ${IMAGE_TAG}"
else
    echo "Using local Docker images (not using registry)"
fi

# List of subgraphs
SUBGRAPHS=("checkout" "discovery" "inventory" "orders" "products" "reviews" "shipping" "users")

# Deploy each subgraph
for subgraph in "${SUBGRAPHS[@]}"; do
    echo ""
    echo "Deploying ${subgraph}..."
    
    # Create namespace
    kubectl create namespace "${subgraph}" --dry-run=client -o yaml | kubectl apply -f -
    
    # Use environment-specific values file if it exists, otherwise use default
    VALUES_FILE="subgraphs/${subgraph}/deploy/environments/${ENVIRONMENT}.yaml"
    if [ ! -f "$VALUES_FILE" ]; then
        VALUES_FILE="subgraphs/${subgraph}/deploy/values.yaml"
    fi
    
    # Verify values file exists
    if [ ! -f "$VALUES_FILE" ]; then
        echo "Error: Values file not found: $VALUES_FILE"
        exit 1
    fi
    
    # Prepare Helm values override for registry if enabled
    HELM_OVERRIDES=""
    if [ -n "$REGISTRY_URL" ]; then
        HELM_OVERRIDES="--set image.repository=${REGISTRY_URL}/${subgraph} --set image.tag=${IMAGE_TAG} --set image.pullPolicy=IfNotPresent"
    fi
    
    # Install using Helm
    helm upgrade --install "${subgraph}" "subgraphs/${subgraph}/deploy" \
        -f "$VALUES_FILE" \
        $HELM_OVERRIDES \
        -n "${subgraph}" \
        --wait
    
    # Create Subgraph CRD
    echo "Creating Subgraph CRD for ${subgraph}..."
    
    # Create Subgraph CRD YAML
    if [ -n "$REGISTRY_URL" ]; then
        # Use OCI image schema when registry is enabled
        # Schema is stored in the OCI image, so we don't need to read the schema file
        # Use ClusterIP for operator (avoids DNS resolution issues, HTTP-only registry)
        echo "Creating Subgraph CRD with OCI image schema for ${subgraph}..."
        cat <<EOF | kubectl apply -f -
apiVersion: apollographql.com/v1alpha2
kind: Subgraph
metadata:
  name: ${subgraph}
  namespace: ${subgraph}
  labels:
    app: ${subgraph}
    apollo.io/subgraph: "true"
spec:
  endpoint: http://graphql.${subgraph}.svc.cluster.local:4001
  schema:
    ociImage:
      reference: ${REGISTRY_URL_FOR_OPERATOR}/${subgraph}:${IMAGE_TAG}
      path: /usr/src/app/schema.graphql
EOF
    else
        # Use inline SDL when registry is not enabled
        # Read schema file and include it inline in the CRD
        echo "Creating Subgraph CRD with inline SDL for ${subgraph}..."
        SCHEMA_FILE="subgraphs/${subgraph}/schema.graphql"
        if [ ! -f "$SCHEMA_FILE" ]; then
            echo "Error: Schema file not found: $SCHEMA_FILE"
            exit 1
        fi
        
        # Read schema and indent for YAML (6 spaces to be indented relative to 'sdl:')
        SCHEMA_CONTENT=$(cat "$SCHEMA_FILE" | sed 's/^/      /')
        
        TEMP_TEMPLATE=$(mktemp)
        TEMP_SCHEMA=$(mktemp)
        echo "$SCHEMA_CONTENT" > "$TEMP_SCHEMA"
        sed "s/\${SUBGRAPH_NAME}/${subgraph}/g" deploy/operator-resources/subgraph.yaml.template > "$TEMP_TEMPLATE"
        # Replace the SCHEMA_CONTENT placeholder line with the actual schema content using sed
        sed "/\${SCHEMA_CONTENT}/r $TEMP_SCHEMA" "$TEMP_TEMPLATE" | sed '/\${SCHEMA_CONTENT}/d' | kubectl apply -f -
        rm -f "$TEMP_TEMPLATE" "$TEMP_SCHEMA"
    fi
    
    echo "✓ ${subgraph} deployed successfully"
done

echo ""
echo "✓ All subgraphs deployed!"
echo ""
echo "Monitor subgraph status with:"
echo "  kubectl get subgraphs --all-namespaces"
echo ""
echo "Next step: Run 06-deploy-coprocessor.sh to deploy the coprocessor"
echo "  Then run 07-deploy-operator-resources.sh to deploy the router"

