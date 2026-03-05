#!/bin/bash
set -euo pipefail

# Cleanup Script for Apollo Federation Supergraph Reference Architecture
# This script removes all Kubernetes resources created by the setup scripts

echo "=== Apollo Federation Supergraph Cleanup Script ==="
echo ""
echo "This will delete:"
echo "  - All Apollo operator and router resources"
echo "  - All subgraph deployments"
echo "  - Coprocessor and client deployments"
echo "  - Telemetry stack"
echo "  - Docker images (optional)"
echo "  - Minikube cluster (optional)"
echo ""

# Load environment if it exists
if [ -f .env ]; then
    source .env
fi

# Set defaults
ENVIRONMENT=${ENVIRONMENT:-dev}
RESOURCE_NAME="reference-architecture-${ENVIRONMENT}"

# Prompt for confirmation
read -p "Are you sure you want to proceed? (yes/no): " -r
if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    echo "Cleanup cancelled"
    exit 0
fi

# Ask about full reset
echo ""
read -p "Delete entire Minikube cluster? This is the cleanest option. (yes/no): " -r
DELETE_CLUSTER=$REPLY

if [[ $DELETE_CLUSTER =~ ^[Yy][Ee][Ss]$ ]]; then
    echo "Deleting Minikube cluster..."
    minikube delete
    echo "✓ Minikube cluster deleted"
    
    # Handle .env file
    if [ -f .env ]; then
        echo ""
        echo "What should we do with .env file?"
        echo "  1) Delete completely"
        echo "  2) Reset to template (keep personal APOLLO_KEY, ENVIRONMENT, CLUSTER_PREFIX)"
        echo "  3) Keep as-is"
        read -p "Choose (1/2/3): " -r ENV_CHOICE
        
        case $ENV_CHOICE in
            1)
                rm -f .env
                echo "✓ .env file deleted"
                ;;
            2)
                # Parse .env file to get the FIRST APOLLO_KEY (personal key, not service key)
                SAVED_APOLLO_KEY=$(grep -m 1 '^export APOLLO_KEY=' .env | sed 's/export APOLLO_KEY=//' | tr -d '"' || echo "")
                SAVED_ENVIRONMENT=$(grep '^export ENVIRONMENT=' .env | sed 's/export ENVIRONMENT=//' | tr -d '"' || echo "dev")
                SAVED_CLUSTER_PREFIX=$(grep '^export CLUSTER_PREFIX=' .env | sed 's/export CLUSTER_PREFIX=//' | tr -d '"' || echo "apollo-supergraph-k8s")
                
                # Reset .env to template
                cat > .env << EOF
# Environment Variables for Minikube Setup

# Apollo GraphOS Personal API Key (required)
# Get it from: https://studio.apollographql.com/user-settings/api-keys
export APOLLO_KEY="${SAVED_APOLLO_KEY}"

# Environment name (required)
# Change this to create a different environment (e.g., "prod", "staging")
export ENVIRONMENT="${SAVED_ENVIRONMENT}"

# Cluster prefix for naming (optional, defaults to "apollo-supergraph-k8s")
export CLUSTER_PREFIX="${SAVED_CLUSTER_PREFIX}"

# The following variables will be set automatically by 02-setup-apollo-graph.sh:
# export APOLLO_GRAPH_ID=""
# export APOLLO_KEY=""  # Graph API key (different from personal API key)
# export OPERATOR_KEY=""
# export ROUTER_URL=""
EOF
                echo "✓ .env file reset to template"
                ;;
            3)
                echo "✓ .env file kept as-is"
                ;;
            *)
                echo "Invalid choice, keeping .env as-is"
                ;;
        esac
    fi
    
    echo ""
    echo "✓ Complete cleanup done!"
    echo "You can start fresh with: ./scripts/minikube/01-setup-minikube.sh"
    exit 0
fi

# Otherwise, do selective cleanup
echo ""
echo "Performing selective cleanup..."

# Step 1: Delete operator-managed CRDs first
echo "Deleting operator-managed CRDs..."
kubectl delete supergraphs ${RESOURCE_NAME} -n apollo --ignore-not-found=true
kubectl delete supergraphschemas ${RESOURCE_NAME} -n apollo --ignore-not-found=true
kubectl delete subgraph --all --all-namespaces --ignore-not-found=true
echo "  ✓ Operator-managed CRDs deleted"

# Step 2: Uninstall Helm releases (proper cleanup before nuking namespaces)
echo "Uninstalling Helm releases..."

# Uninstall operator
helm uninstall apollo-operator -n apollo-operator 2>/dev/null && echo "  ✓ apollo-operator uninstalled" || echo "  apollo-operator not found (ok)"

# Uninstall client
helm uninstall client -n client 2>/dev/null && echo "  ✓ client uninstalled" || echo "  client not found (ok)"

# Uninstall coprocessor
helm uninstall coprocessor -n apollo 2>/dev/null && echo "  ✓ coprocessor uninstalled" || echo "  coprocessor not found (ok)"

# Uninstall all subgraphs
echo "  Uninstalling subgraphs..."
for subgraph in checkout discovery inventory orders products reviews shipping users; do
    helm uninstall $subgraph -n $subgraph 2>/dev/null && echo "    ✓ $subgraph uninstalled" || echo "    $subgraph not found (ok)"
done

# Uninstall monitoring stack
helm uninstall prometheus -n monitoring 2>/dev/null && echo "  ✓ prometheus uninstalled" || echo "  prometheus not found (ok)"

echo "  ✓ All Helm releases uninstalled"

# Step 3: Delete namespaces (cascades remaining resources)
echo "Deleting namespaces..."
NAMESPACES=(
    "apollo"
    "apollo-operator"
    "checkout"
    "discovery"
    "inventory"
    "orders"
    "products"
    "reviews"
    "shipping"
    "users"
    "client"
    "monitoring"
)

for ns in "${NAMESPACES[@]}"; do
    kubectl delete namespace "$ns" --ignore-not-found=true &
done

# Wait for all namespace deletions to complete
echo "  Waiting for namespaces to be deleted..."
wait
echo "  ✓ All namespaces deleted"

# Step 4: Delete CRDs
echo "Deleting Custom Resource Definitions..."
kubectl delete crd supergraphs.apollographql.com --ignore-not-found=true
kubectl delete crd supergraphschemas.apollographql.com --ignore-not-found=true
kubectl delete crd subgraphs.apollographql.com --ignore-not-found=true
kubectl delete crd supergraphsets.apollographql.com --ignore-not-found=true
echo "  ✓ CRDs deleted"

# Step 5: Delete ClusterRoles and ClusterRoleBindings
echo "Deleting ClusterRoles and ClusterRoleBindings..."
kubectl delete clusterrole apollo-operator:subgraph --ignore-not-found=true
kubectl delete clusterrole apollo-operator:supergraph --ignore-not-found=true
kubectl delete clusterrole apollo-operator:supergraph-schema --ignore-not-found=true
kubectl delete clusterrole apollo-operator:supergraph-set --ignore-not-found=true

kubectl delete clusterrolebinding apollo-operator:subgraph --ignore-not-found=true
kubectl delete clusterrolebinding apollo-operator:supergraph --ignore-not-found=true
kubectl delete clusterrolebinding apollo-operator:supergraph-schema --ignore-not-found=true
kubectl delete clusterrolebinding apollo-operator:supergraph-set --ignore-not-found=true
echo "  ✓ ClusterRoles and ClusterRoleBindings deleted"

# Step 6: Optional Docker image cleanup
echo ""
read -p "Clean up local Docker images? (yes/no): " -r
if [[ $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    echo "Cleaning up Docker images..."
    
    # Switch to Minikube's Docker daemon
    eval $(minikube docker-env)
    
    # Delete subgraph images
    for subgraph in checkout discovery inventory orders products reviews shipping users; do
        docker rmi ${subgraph}:local 2>/dev/null && echo "  ✓ Deleted ${subgraph}:local" || echo "  ${subgraph}:local not found (ok)"
    done
    
    # Delete other images
    docker rmi coprocessor:local 2>/dev/null && echo "  ✓ Deleted coprocessor:local" || echo "  coprocessor:local not found (ok)"
    docker rmi client:local 2>/dev/null && echo "  ✓ Deleted client:local" || echo "  client:local not found (ok)"
    
    echo "  ✓ Docker images cleaned up"
else
    echo "  Skipping Docker image cleanup"
fi

# Step 7: Handle .env file
if [ -f .env ]; then
    echo ""
    echo "What should we do with .env file?"
    echo "  1) Delete completely"
    echo "  2) Reset to template (keep personal APOLLO_KEY, ENVIRONMENT, CLUSTER_PREFIX)"
    echo "  3) Keep as-is"
    read -p "Choose (1/2/3): " -r ENV_CHOICE
    
    case $ENV_CHOICE in
        1)
            rm -f .env
            echo "✓ .env file deleted"
            ;;
        2)
            # Parse .env file to get the FIRST APOLLO_KEY (personal key, not service key)
            SAVED_APOLLO_KEY=$(grep -m 1 '^export APOLLO_KEY=' .env | sed 's/export APOLLO_KEY=//' | tr -d '"' || echo "")
            SAVED_ENVIRONMENT=$(grep '^export ENVIRONMENT=' .env | sed 's/export ENVIRONMENT=//' | tr -d '"' || echo "dev")
            SAVED_CLUSTER_PREFIX=$(grep '^export CLUSTER_PREFIX=' .env | sed 's/export CLUSTER_PREFIX=//' | tr -d '"' || echo "apollo-supergraph-k8s")
            
            # Reset .env to template
            cat > .env << EOF
# Environment Variables for Minikube Setup

# Apollo GraphOS Personal API Key (required)
# Get it from: https://studio.apollographql.com/user-settings/api-keys
export APOLLO_KEY="${SAVED_APOLLO_KEY}"

# Environment name (required)
# Change this to create a different environment (e.g., "prod", "staging")
export ENVIRONMENT="${SAVED_ENVIRONMENT}"

# Cluster prefix for naming (optional, defaults to "apollo-supergraph-k8s")
export CLUSTER_PREFIX="${SAVED_CLUSTER_PREFIX}"

# The following variables will be set automatically by 02-setup-apollo-graph.sh:
# export APOLLO_GRAPH_ID=""
# export APOLLO_KEY=""  # Graph API key (different from personal API key)
# export OPERATOR_KEY=""
# export ROUTER_URL=""
EOF
            echo "✓ .env file reset to template"
            ;;
        3)
            echo "✓ .env file kept as-is"
            ;;
        *)
            echo "Invalid choice, keeping .env as-is"
            ;;
    esac
fi

echo ""
echo "✓ Selective cleanup complete!"
echo ""
echo "Your Minikube cluster is still running with core components."
echo "To start fresh:"
echo "  1. Run: ./scripts/minikube/02-setup-apollo-graph.sh"
echo "  2. Then continue with scripts 03-10"
echo ""
echo "Or for a completely clean slate, run this script again and choose to delete the Minikube cluster."