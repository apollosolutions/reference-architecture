# Cleanup

⏱ Estimated time: 5 minutes

This guide covers cleaning up all resources deployed to your local Minikube cluster.

## Delete Operator-Managed Resources

Before deleting Kubernetes resources, first remove the operator-managed CRDs. Make sure you have your `ENVIRONMENT` variable set (or load it from `.env`):

```bash
# Load environment variables if needed
if [ -f .env ]; then
    source .env
fi

ENVIRONMENT=${ENVIRONMENT:-dev}
RESOURCE_NAME="reference-architecture-${ENVIRONMENT}"
```

Delete operator-managed resources:

```bash
# Delete Supergraph resources (this deletes the router deployment)
kubectl delete supergraphs ${RESOURCE_NAME} -n apollo || true

# Delete SupergraphSchema resources
kubectl delete supergraphschemas ${RESOURCE_NAME} -n apollo || true

# Delete Ingress resources
kubectl delete ingress router -n apollo || true
kubectl delete ingress client -n client || true

# Delete Subgraph resources (this will also stop schema publishing)
kubectl delete subgraph --all --all-namespaces || true
```

## Uninstall Helm Releases

Uninstall all Helm releases:

```bash
# Uninstall client (if deployed)
helm uninstall client -n client || true

# Uninstall coprocessor (if deployed)
helm uninstall coprocessor -n apollo || true

# Uninstall subgraph Helm releases
for subgraph in checkout discovery inventory orders products reviews shipping users; do
  helm uninstall $subgraph -n $subgraph || true
done
```

## Delete Namespaces

Delete all application namespaces:

```bash
# Delete subgraph namespaces
kubectl delete namespace checkout discovery inventory orders products reviews shipping users || true

# Delete client namespace
kubectl delete namespace client || true

# Delete operator API key secret (contains sensitive data)
kubectl delete secret apollo-api-key -n apollo-operator || true

# Uninstall the Apollo GraphOS Operator
helm uninstall apollo-operator -n apollo-operator || true

# Delete operator namespaces
kubectl delete namespace apollo-operator apollo || true
```

## Clean Up Apollo GraphOS Resources (Optional)

If you want to clean up the Apollo GraphOS graph and variants you created:

1. Go to [Apollo GraphOS Studio](https://studio.apollographql.com)
2. Navigate to your graph
3. Delete the graph or specific variants as needed

**Note:** The operator API key created during setup will remain in your Apollo GraphOS account. You can delete it from [User Settings > API Keys](https://studio.apollographql.com/user-settings/api-keys) if desired.

## Delete Minikube Cluster (Optional)

If you want to completely remove the Minikube cluster:

```bash
# Stop the cluster
minikube stop

# Delete the cluster
minikube delete
```

Or if you have multiple Minikube profiles and want to delete all:

```bash
minikube delete --all
```

## Clean Up Local Docker Images (Optional)

If you want to remove the local Docker images built for this project:

```bash
# Configure Docker to use Minikube's daemon (if cluster is still running)
eval $(minikube docker-env)

# Remove local images
docker rmi checkout:local discovery:local inventory:local orders:local \
  products:local reviews:local shipping:local users:local \
  coprocessor:local client:local || true
```

## Clean Up Environment Variables (Optional)

If you want to remove the `.env` file created during setup:

```bash
rm .env
```

**Note:** This will remove your Apollo GraphOS configuration. You'll need to run `02-setup-apollo-graph.sh` again if you want to recreate the graph.
