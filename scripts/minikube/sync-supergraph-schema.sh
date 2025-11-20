#!/bin/bash
set -euo pipefail

# Script: Sync Supergraph Schema from GraphOS to Local OCI Registry
# This script fetches the composed supergraph schema from GraphOS Platform API
# and pushes it to the local OCI registry for use by the Apollo Router.

echo "=== Syncing Supergraph Schema to Local OCI Registry ==="

# Load environment variables from .env if it exists
if [ -f .env ]; then
    echo "Loading environment variables from .env..."
    source .env
fi

# Validate required variables
if [[ -z "${ENVIRONMENT:-}" ]]; then
    ENVIRONMENT="dev"
    echo "ENVIRONMENT not set, defaulting to: ${ENVIRONMENT}"
fi

if [[ -z "${APOLLO_GRAPH_ID:-}" ]]; then
    echo "Error: APOLLO_GRAPH_ID is not set"
    echo "Please set APOLLO_GRAPH_ID in your .env file or export it:"
    echo "  export APOLLO_GRAPH_ID=\"your-graph-id\""
    exit 1
fi

if [[ -z "${APOLLO_KEY:-}" ]]; then
    echo "Error: APOLLO_KEY is not set"
    echo "Please set APOLLO_KEY in your .env file or export it:"
    echo "  export APOLLO_KEY=\"your-apollo-key\""
    exit 1
fi

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo "Error: kubectl is not installed"
    exit 1
fi

# Check if oras is available
if ! command -v oras &> /dev/null; then
    echo "Error: oras CLI is not installed"
    echo "Please run 03a-setup-registry.sh to install oras"
    exit 1
fi

# Check if jq is available
if ! command -v jq &> /dev/null; then
    echo "Error: jq is not installed"
    echo "Please install jq: https://stedolan.github.io/jq/download/"
    exit 1
fi

# Verify cluster connection
if ! kubectl cluster-info &> /dev/null; then
    echo "Error: Cannot connect to Kubernetes cluster"
    exit 1
fi

# Resource name based on environment
RESOURCE_NAME="reference-architecture-${ENVIRONMENT}"

# Check if SupergraphSchema CRD exists
echo "Checking SupergraphSchema status..."
if ! kubectl get supergraphschema "${RESOURCE_NAME}" -n apollo &>/dev/null; then
    echo "Error: SupergraphSchema '${RESOURCE_NAME}' not found in namespace 'apollo'"
    echo "Please ensure the SupergraphSchema CRD is deployed"
    exit 1
fi

# Check if composition is complete
AVAILABLE_CONDITION=$(kubectl get supergraphschema "${RESOURCE_NAME}" -n apollo -o jsonpath='{.status.conditions[?(@.type=="Available")].status}' 2>/dev/null || echo "False")
COMPOSITION_PENDING=$(kubectl get supergraphschema "${RESOURCE_NAME}" -n apollo -o jsonpath='{.status.conditions[?(@.type=="CompositionPending")].status}' 2>/dev/null || echo "True")

if [[ "$AVAILABLE_CONDITION" != "True" ]] || [[ "$COMPOSITION_PENDING" == "True" ]]; then
    echo "Warning: Composition may not be complete"
    echo "  Available: ${AVAILABLE_CONDITION}"
    echo "  CompositionPending: ${COMPOSITION_PENDING}"
    echo ""
    echo "Continuing anyway, but the schema may not be ready..."
fi

# Get registry service details
echo "Getting registry service details..."
REGISTRY_PORT=$(kubectl get svc registry -n kube-system -o jsonpath='{.spec.ports[?(@.name=="http")].port}' 2>/dev/null || echo "")

if [ -z "$REGISTRY_PORT" ] || [ "$REGISTRY_PORT" == "null" ]; then
    echo "Error: Could not determine registry port"
    echo "Please ensure the registry is set up by running 03a-setup-registry.sh"
    exit 1
fi

# Get host-accessible registry URL
# Minikube registry addon doesn't expose NodePort by default, so we need port forwarding
# Default to localhost:5000 (common Minikube registry port when forwarded)
REGISTRY_URL="localhost:5000"

# Check if port forwarding is already set up by testing connectivity
if curl -s --max-time 2 "http://${REGISTRY_URL}/v2/" >/dev/null 2>&1; then
    echo "✓ Registry accessible at ${REGISTRY_URL} (port forwarding appears to be active)"
else
    echo "Registry not accessible at ${REGISTRY_URL}"
    echo ""
    echo "Setting up port forwarding in the background..."
    echo "  This will forward registry service port ${REGISTRY_PORT} to localhost:5000"
    echo ""
    
    # Start port forwarding in the background
    PORT_FORWARD_PID=$(kubectl port-forward -n kube-system service/registry 5000:${REGISTRY_PORT} >/dev/null 2>&1 & echo $!)
    
    # Wait a moment for port forward to establish
    sleep 2
    
    # Check if port forward process is still running
    if ! kill -0 "$PORT_FORWARD_PID" 2>/dev/null; then
        echo "Error: Failed to set up port forwarding"
        echo ""
        echo "Please set up port forwarding manually in another terminal:"
        echo "  kubectl port-forward -n kube-system service/registry 5000:${REGISTRY_PORT}"
        echo ""
        echo "Then run this script again."
        exit 1
    fi
    
    # Verify port forwarding is working
    if curl -s --max-time 2 "http://${REGISTRY_URL}/v2/" >/dev/null 2>&1; then
        echo "✓ Port forwarding established successfully"
        echo "  Note: Port forwarding will stop when this script exits"
        # Set up cleanup trap to kill port forward on exit
        trap "kill $PORT_FORWARD_PID 2>/dev/null || true" EXIT
    else
        echo "Warning: Port forwarding may not be working yet"
        echo "  Continuing anyway..."
    fi
fi

# Query GraphOS Platform API for latest build
echo ""
echo "Querying GraphOS Platform API for latest schema..."
GRAPH_REF="${APOLLO_GRAPH_ID}@${ENVIRONMENT}"

QUERY='query GetLatestBuildByVariantId($ref: ID!) {
  variant(ref: $ref) {
    ... on GraphVariant {
      latestLaunch {
        graphArtifact {
          digest
          content {
            build {
              result {
                ... on BuildSuccess {
                  coreSchema {
                    coreDocument
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}'

QUERY_RESPONSE=$(curl -s \
    --header "x-api-key: ${APOLLO_KEY}" \
    --header "content-type: application/json" \
    --header "apollographql-client-name: reference-architecture" \
    --url 'https://graphql.api.apollographql.com/api/graphql' \
    --data "{\"query\":$(echo "$QUERY" | jq -Rs .),\"variables\":{\"ref\":\"${GRAPH_REF}\"}}")

# Check for errors in response
ERROR=$(echo "$QUERY_RESPONSE" | jq -r '.errors[0].message // empty')
if [ -n "$ERROR" ]; then
    echo "Error: GraphOS API returned an error:"
    echo "$ERROR"
    echo ""
    echo "Full response:"
    echo "$QUERY_RESPONSE" | jq .
    exit 1
fi

# Extract digest and schema
DIGEST=$(echo "$QUERY_RESPONSE" | jq -r '.data.variant.latestLaunch.graphArtifact.digest // empty')
SCHEMA_CONTENT=$(echo "$QUERY_RESPONSE" | jq -r '.data.variant.latestLaunch.graphArtifact.content.build.result.coreSchema.coreDocument // empty')

# Check if variant exists
VARIANT_EXISTS=$(echo "$QUERY_RESPONSE" | jq -r '.data.variant // empty')
if [ -z "$VARIANT_EXISTS" ] || [ "$VARIANT_EXISTS" == "null" ]; then
    echo "Error: Graph variant '${GRAPH_REF}' not found"
    echo "Response:"
    echo "$QUERY_RESPONSE" | jq .
    exit 1
fi

# Check if launch exists
LAUNCH_EXISTS=$(echo "$QUERY_RESPONSE" | jq -r '.data.variant.latestLaunch // empty')
if [ -z "$LAUNCH_EXISTS" ] || [ "$LAUNCH_EXISTS" == "null" ]; then
    echo "Error: No launch found for variant '${GRAPH_REF}'"
    echo "Please ensure a schema has been published and composed"
    exit 1
fi

if [ -z "$DIGEST" ] || [ "$DIGEST" == "null" ]; then
    echo "Error: Could not get artifact digest from GraphOS"
    echo "Response:"
    echo "$QUERY_RESPONSE" | jq .
    exit 1
fi

if [ -z "$SCHEMA_CONTENT" ] || [ "$SCHEMA_CONTENT" == "null" ]; then
    echo "Error: Could not get schema content from GraphOS"
    echo "The build may not have completed successfully"
    echo "Response:"
    echo "$QUERY_RESPONSE" | jq .
    exit 1
fi

echo "✓ Retrieved schema (digest: ${DIGEST})"

# Create temporary file for schema
TEMP_SCHEMA=$(mktemp)
echo "$SCHEMA_CONTENT" > "$TEMP_SCHEMA"
echo "✓ Schema written to temporary file"

# Push to local registry using oras
echo ""
echo "Pushing schema to local registry..."

# Extract just the SHA256 hash (without the "sha256:" prefix if present)
SHA256_HASH="${DIGEST#sha256:}"

# Push with both :latest and :sha256-{hash} tags
# Note: Using hyphen instead of colon because OCI tags cannot contain colons
ARTIFACT_REF_LATEST="${REGISTRY_URL}/supergraph-schema:latest"
ARTIFACT_REF_SHA="${REGISTRY_URL}/supergraph-schema:sha256-${SHA256_HASH}"

# Use oras push with appropriate media type for GraphQL supergraph schema
# The media type should match what the operator expects: application/vnd.apollographql.schema
# --disable-path-validation is needed because mktemp creates absolute paths
echo "  Pushing to :latest..."
if oras push --plain-http --disable-path-validation \
    "${ARTIFACT_REF_LATEST}" \
    "${TEMP_SCHEMA}:application/vnd.apollographql.schema"; then
    echo "  ✓ Schema pushed to ${ARTIFACT_REF_LATEST}"
else
    echo "Error: Failed to push schema to registry (latest tag)"
    rm -f "$TEMP_SCHEMA"
    exit 1
fi

echo "  Pushing to :sha256-${SHA256_HASH}..."
if oras push --plain-http --disable-path-validation \
    "${ARTIFACT_REF_SHA}" \
    "${TEMP_SCHEMA}:application/vnd.apollographql.schema"; then
    echo "  ✓ Schema pushed to ${ARTIFACT_REF_SHA}"
else
    echo "Error: Failed to push schema to registry (SHA256 tag)"
    rm -f "$TEMP_SCHEMA"
    exit 1
fi

# Clean up temporary file
rm -f "$TEMP_SCHEMA"

echo ""
echo "✓ Supergraph schema sync complete!"
echo ""
echo "Schema is now available at:"
echo "  - ${ARTIFACT_REF_LATEST} (for dev environment)"
echo "  - ${ARTIFACT_REF_SHA} (versioned)"
echo ""
echo "The Supergraph CRD should automatically pick up the new schema from :latest."
echo ""
echo "Monitor router status with:"
echo "  kubectl get supergraph ${RESOURCE_NAME} -n apollo"
echo "  kubectl get pods -n apollo"
echo ""

