#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Apollo MCP Server Installation Script ===${NC}\n"

# Step 1: Check prerequisites
echo -e "${YELLOW}[1/5] Checking prerequisites...${NC}"

if ! command -v minikube &> /dev/null; then
    echo -e "${RED}Error: minikube is not installed${NC}"
    exit 1
fi

if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}Error: kubectl is not installed${NC}"
    exit 1
fi

if ! command -v helm &> /dev/null; then
    echo -e "${RED}Error: helm is not installed${NC}"
    exit 1
fi

echo -e "${GREEN}✓ All prerequisites found${NC}\n"

# Step 2: Verify minikube is running
echo -e "${YELLOW}[2/5] Checking minikube status...${NC}"

if ! minikube status &> /dev/null; then
    echo -e "${RED}Error: minikube is not running${NC}"
    echo "Start minikube with: minikube start"
    exit 1
fi

echo -e "${GREEN}✓ Minikube is running${NC}\n"

# Step 3: Create namespace if it doesn't exist
echo -e "${YELLOW}[3/5] Ensuring 'apollo' namespace exists...${NC}"

kubectl create namespace apollo --dry-run=client -o yaml | kubectl apply -f -

echo -e "${GREEN}✓ Namespace ready${NC}\n"

# Step 4: Create GraphOS credentials secret
echo -e "${YELLOW}[4/6] Creating GraphOS credentials secret...${NC}"

if [ -f .env ]; then
  source .env
else
  echo -e "${RED}Error: .env file not found${NC}"
  exit 1
fi

# Construct graph ref from existing .env values
APOLLO_GRAPH_REF="${APOLLO_GRAPH_ID}@${ENVIRONMENT}"

# Set k8s secret for the graph ref and key which will be loaded in the deployemnt as an env variable
kubectl create secret generic apollo-mcp-credentials \
  --from-literal=APOLLO_GRAPH_REF="${APOLLO_GRAPH_REF}" \
  --from-literal=APOLLO_KEY="${APOLLO_KEY}" \
  --namespace apollo \
  --dry-run=client -o yaml | kubectl apply -f -

if [ $? -ne 0 ]; then
    echo -e "${RED}Error: Failed to create secret${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Secret created${NC}\n"

# Step 4: Install/upgrade Helm chart
echo -e "${YELLOW}[5/6] Installing Apollo MCP Server...${NC}"

helm upgrade --install mcp-server deploy/mcp-server \
  --namespace apollo \
  --create-namespace \
  --wait

if [ $? -ne 0 ]; then
    echo -e "${RED}Error: Helm installation failed${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Helm chart installed${NC}\n"

# Step 5: Wait for deployment to be ready
echo -e "${YELLOW}[6/6] Waiting for pod to be ready...${NC}"

kubectl wait --for=condition=ready pod \
  -l app=mcp-server \
  -n apollo \
  --timeout=60s

if [ $? -ne 0 ]; then
    echo -e "${RED}Error: Pod did not become ready${NC}"
    echo "Check pod status with: kubectl get pods -n apollo"
    echo "Check logs with: kubectl logs -n apollo -l app=mcp-server"
    exit 1
fi

echo -e "${GREEN}✓ Pod is ready!${NC}\n"

# Success message
echo -e "${GREEN}=== Installation Complete! ===${NC}\n"
echo "Your Apollo MCP Server is now running in the 'apollo' namespace."
echo ""
echo "To access it locally, run:"
echo -e "${YELLOW}  kubectl port-forward -n apollo svc/mcp-server-service 5001:8000${NC}"
echo ""
echo "Then configure your MCP client to connect to:"
echo -e "${YELLOW}  http://localhost:5001${NC}"
echo ""
echo "To check the status:"
echo "  kubectl get pods -n apollo"
echo "  kubectl logs -n apollo -l app=mcp-server"