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
    
    # Install using Helm
    helm upgrade --install "${subgraph}" "subgraphs/${subgraph}/deploy" \
        -f "$VALUES_FILE" \
        -n "${subgraph}" \
        --wait
    
    # Create Subgraph CRD with inline SDL
    echo "Creating Subgraph CRD for ${subgraph}..."
    
    SCHEMA_FILE="subgraphs/${subgraph}/schema.graphql"
    if [ ! -f "$SCHEMA_FILE" ]; then
        echo "Error: Schema file not found: $SCHEMA_FILE"
        exit 1
    fi
    
    # Read schema and indent for YAML (6 spaces to be indented relative to 'sdl:')
    SCHEMA_CONTENT=$(cat "$SCHEMA_FILE" | sed 's/^/      /')
    
    # Create Subgraph CRD YAML using template
    # Replace SUBGRAPH_NAME, then replace SCHEMA_CONTENT placeholder with actual schema
    TEMP_TEMPLATE=$(mktemp)
    TEMP_SCHEMA=$(mktemp)
    echo "$SCHEMA_CONTENT" > "$TEMP_SCHEMA"
    sed "s/\${SUBGRAPH_NAME}/${subgraph}/g" deploy/operator-resources/subgraph.yaml.template > "$TEMP_TEMPLATE"
    # Replace the SCHEMA_CONTENT placeholder line with the actual schema content using sed
    sed "/\${SCHEMA_CONTENT}/r $TEMP_SCHEMA" "$TEMP_TEMPLATE" | sed '/\${SCHEMA_CONTENT}/d' | kubectl apply -f -
    rm -f "$TEMP_TEMPLATE" "$TEMP_SCHEMA"
    
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

