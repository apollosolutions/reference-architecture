#!/bin/bash
set -euo pipefail

# Script 12a: Start port-forwards for the Apollo MCP Server
# Starts both the MCP server and OAuth auth server port-forwards in the background,
# adds the /etc/hosts entry if missing, and verifies connectivity.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

NAMESPACE="apollo"
AUTH_NAMESPACE="users"
MCP_LOCAL_PORT=5001
MCP_REMOTE_PORT=8000
AUTH_LOCAL_PORT=4001
AUTH_REMOTE_PORT=4001
AUTH_HOSTNAME="graphql.users.svc.cluster.local"

echo -e "${GREEN}=== MCP Server Port Forwards ===${NC}"
echo ""

# Check prerequisites
if ! command -v kubectl &> /dev/null; then
  echo -e "${RED}Error: kubectl is not installed.${NC}"
  exit 1
fi

if ! kubectl cluster-info &> /dev/null 2>&1; then
  echo -e "${RED}Error: Cannot connect to Kubernetes cluster.${NC}"
  exit 1
fi

# Verify the MCP server pod is running
MCP_READY=$(kubectl get pods -n "$NAMESPACE" -l app=apollo-mcp-server --no-headers 2>/dev/null | grep -c "Running" || true)
if [ "$MCP_READY" -eq 0 ]; then
  echo -e "${RED}Error: Apollo MCP Server is not running in the '$NAMESPACE' namespace.${NC}"
  echo "Deploy it first with: ./scripts/minikube/12-deploy-mcp-server.sh"
  exit 1
fi

# Verify the auth server pod is running
AUTH_READY=$(kubectl get pods -n "$AUTH_NAMESPACE" --no-headers 2>/dev/null | grep -c "Running" || true)
if [ "$AUTH_READY" -eq 0 ]; then
  echo -e "${RED}Error: Users subgraph (auth server) is not running in the '$AUTH_NAMESPACE' namespace.${NC}"
  echo "Deploy subgraphs first with: ./scripts/minikube/05-deploy-subgraphs.sh"
  exit 1
fi

# Kill any existing port-forwards on these ports
for port in $MCP_LOCAL_PORT $AUTH_LOCAL_PORT; do
  pid=$(lsof -ti:"$port" 2>/dev/null || true)
  if [ -n "$pid" ]; then
    echo "Killing existing process on port $port (PID $pid)..."
    kill -9 $pid 2>/dev/null || true
    sleep 1
  fi
done

# Start MCP server port-forward
echo "Starting MCP server port-forward (localhost:$MCP_LOCAL_PORT -> svc/apollo-mcp-server:$MCP_REMOTE_PORT)..."
kubectl port-forward -n "$NAMESPACE" svc/apollo-mcp-server "$MCP_LOCAL_PORT:$MCP_REMOTE_PORT" &
MCP_PF_PID=$!

# Start auth server port-forward
echo "Starting auth server port-forward (localhost:$AUTH_LOCAL_PORT -> svc/graphql:$AUTH_REMOTE_PORT)..."
kubectl port-forward -n "$AUTH_NAMESPACE" svc/graphql "$AUTH_LOCAL_PORT:$AUTH_REMOTE_PORT" &
AUTH_PF_PID=$!

# Wait for port-forwards to establish
echo ""
echo "Waiting for port-forwards to establish..."
sleep 3

# Verify port-forwards are alive
FAILED=false

if ! kill -0 $MCP_PF_PID 2>/dev/null; then
  echo -e "${RED}MCP server port-forward failed to start.${NC}"
  FAILED=true
fi

if ! kill -0 $AUTH_PF_PID 2>/dev/null; then
  echo -e "${RED}Auth server port-forward failed to start.${NC}"
  FAILED=true
fi

if [ "$FAILED" = true ]; then
  echo -e "${RED}One or more port-forwards failed. Check the output above for errors.${NC}"
  exit 1
fi

# Check /etc/hosts entry
echo ""
if grep -q "$AUTH_HOSTNAME" /etc/hosts 2>/dev/null; then
  echo -e "${GREEN}/etc/hosts already has an entry for $AUTH_HOSTNAME${NC}"
else
  echo -e "${YELLOW}Missing /etc/hosts entry for $AUTH_HOSTNAME${NC}"
  echo ""
  echo "The MCP OAuth flow requires this DNS entry. Run:"
  echo -e "  ${YELLOW}echo '127.0.0.1 $AUTH_HOSTNAME' | sudo tee -a /etc/hosts${NC}"
  echo ""
  read -p "Add it now? (requires sudo password) [y/N] " -n 1 -r
  echo ""
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "127.0.0.1 $AUTH_HOSTNAME" | sudo tee -a /etc/hosts
    echo -e "${GREEN}Added /etc/hosts entry.${NC}"
  else
    echo -e "${YELLOW}Skipped. You'll need to add it manually before connecting MCP clients.${NC}"
  fi
fi

# Verify connectivity
echo ""
echo "Verifying connectivity..."

MCP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:$MCP_LOCAL_PORT/mcp" 2>/dev/null || echo "000")
AUTH_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:$AUTH_LOCAL_PORT/.well-known/oauth-authorization-server" 2>/dev/null || echo "000")

if [ "$MCP_STATUS" = "401" ]; then
  echo -e "  MCP server:  ${GREEN}reachable${NC} (HTTP 401 — auth required, as expected)"
else
  echo -e "  MCP server:  ${RED}HTTP $MCP_STATUS${NC}"
fi

if [ "$AUTH_STATUS" = "200" ]; then
  echo -e "  Auth server: ${GREEN}reachable${NC} (HTTP 200)"
else
  echo -e "  Auth server: ${RED}HTTP $AUTH_STATUS${NC}"
fi

echo ""
echo -e "${GREEN}=== Port Forwards Running ===${NC}"
echo ""
echo -e "  MCP server:  ${YELLOW}http://localhost:$MCP_LOCAL_PORT/mcp${NC}  (PID $MCP_PF_PID)"
echo -e "  Auth server: ${YELLOW}http://localhost:$AUTH_LOCAL_PORT${NC}       (PID $AUTH_PF_PID)"
echo ""
echo -e "To stop port-forwards:"
echo -e "  ${YELLOW}kill $MCP_PF_PID $AUTH_PF_PID${NC}"
echo ""
echo -e "Connect your MCP client to: ${YELLOW}http://localhost:$MCP_LOCAL_PORT/mcp${NC}"
echo ""

# Wait for both background processes (keeps the script running)
echo "Press Ctrl+C to stop all port-forwards."
wait
