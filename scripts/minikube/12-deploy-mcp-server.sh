#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Apollo MCP Server Deployment ===${NC}"
echo ""

# Check prerequisites
for cmd in minikube kubectl helm; do
  if ! command -v $cmd &> /dev/null; then
    echo -e "${RED}Error: $cmd is not installed.${NC}"
    exit 1
  fi
done

# Verify minikube is running
if ! minikube status --format='{{.Host}}' 2>/dev/null | grep -q "Running"; then
  echo -e "${RED}Error: Minikube is not running. Start it with 'minikube start'.${NC}"
  exit 1
fi

echo -e "${GREEN}Prerequisites check passed.${NC}"
echo ""

# Load environment variables
if [ -f "$REPO_ROOT/.env" ]; then
  source "$REPO_ROOT/.env"
else
  echo -e "${RED}Error: .env file not found at $REPO_ROOT/.env${NC}"
  echo "Run script 02 first to generate the .env file."
  exit 1
fi

# Validate required environment variables
if [ -z "${APOLLO_GRAPH_REF:-}" ]; then
  echo -e "${RED}Error: APOLLO_GRAPH_REF is not set in .env${NC}"
  echo "Run script 02 first to set up the Apollo graph."
  exit 1
fi

if [ -z "${APOLLO_KEY:-}" ]; then
  echo -e "${RED}Error: APOLLO_KEY is not set in .env${NC}"
  exit 1
fi

NAMESPACE="apollo"
ENVIRONMENT="${ENVIRONMENT:-dev}"

# Ensure namespace exists
if ! kubectl get namespace "$NAMESPACE" &>/dev/null; then
  echo "Creating namespace '$NAMESPACE'..."
  kubectl create namespace "$NAMESPACE"
fi

# Create or update the MCP credentials secret
echo "Creating MCP credentials secret..."
kubectl create secret generic apollo-mcp-credentials \
  --namespace "$NAMESPACE" \
  --from-literal=APOLLO_GRAPH_REF="$APOLLO_GRAPH_REF" \
  --from-literal=APOLLO_KEY="$APOLLO_KEY" \
  --from-literal=ROUTER_ENDPOINT="http://reference-architecture-${ENVIRONMENT}.${NAMESPACE}.svc.cluster.local:80" \
  --from-literal=MCP_RESOURCE_URL="http://localhost:5001/mcp" \
  --from-literal=AUTH_SERVER_URL="http://localhost:4001" \
  --dry-run=client -o yaml | kubectl apply -f -

echo -e "${GREEN}MCP credentials secret created/updated.${NC}"
echo ""

# Install/upgrade the Helm chart
echo "Deploying Apollo MCP Server via Helm..."
helm upgrade --install apollo-mcp-server \
  "$REPO_ROOT/deploy/apollo-mcp-server" \
  --namespace "$NAMESPACE" \
  --wait \
  --timeout 120s

echo -e "${GREEN}Helm release installed/upgraded.${NC}"
echo ""

# Wait for the pod to be ready
echo "Waiting for MCP server pod to be ready..."
kubectl wait --for=condition=ready pod \
  -l app=apollo-mcp-server \
  -n "$NAMESPACE" \
  --timeout=120s

echo ""
echo -e "${GREEN}=== Apollo MCP Server Deployed Successfully ===${NC}"
echo ""
echo -e "To access the MCP server locally, start both port-forwards:"
echo ""
echo -e "  ${YELLOW}# Terminal 1: MCP server${NC}"
echo -e "  ${YELLOW}kubectl port-forward -n $NAMESPACE svc/apollo-mcp-server 5001:8000${NC}"
echo ""
echo -e "  ${YELLOW}# Terminal 2: Auth server (users subgraph for OAuth)${NC}"
echo -e "  ${YELLOW}kubectl port-forward -n users svc/graphql 4001:4001${NC}"
echo ""
echo -e "Then configure your MCP client to connect to:"
echo -e "  ${YELLOW}http://localhost:5001/mcp${NC}"
echo ""
echo -e "Add a DNS entry so your machine can reach the OAuth server by its in-cluster name:"
echo -e "  ${YELLOW}echo '127.0.0.1 graphql.users.svc.cluster.local' | sudo tee -a /etc/hosts${NC}"
echo ""
echo -e "Example: Add to Claude Desktop config (~/Library/Application Support/Claude/claude_desktop_config.json):"
echo -e '  {
    "mcpServers": {
      "apollo-reference-arch": {
        "command": "npx",
        "args": ["mcp-remote", "http://localhost:5001/mcp", "--transport", "http-only"]
      }
    }
  }'
echo ""
echo -e "To test with MCP Inspector:"
echo -e "  ${YELLOW}npx @modelcontextprotocol/inspector http://localhost:5001/mcp --transport http${NC}"
echo ""
echo -e "For full instructions, see docs/setup.md (Step 6) and docs/mcp-production.md."
echo ""
