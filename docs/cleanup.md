# Cleanup

⏱ Estimated time: 5 minutes

This guide covers cleaning up all resources deployed to your local Minikube cluster.

## Delete Operator-Managed Resources

Before deleting Kubernetes resources, first remove the operator-managed CRDs. The operator creates and manages these resources, so they should be deleted before Helm releases. Make sure you have your `ENVIRONMENT` variable set (or load it from `.env`):

```bash
if [ -f .env ]; then
    source .env
fi

ENVIRONMENT=${ENVIRONMENT:-dev}
RESOURCE_NAME="reference-architecture-${ENVIRONMENT}"
```

Delete operator-managed CRDs:

```bash
kubectl delete supergraphs ${RESOURCE_NAME} -n apollo || true
kubectl delete supergraphschemas ${RESOURCE_NAME} -n apollo || true
kubectl delete subgraph --all --all-namespaces || true
```

**Note:** The client's Ingress resource is managed by Helm and will be automatically deleted when you uninstall the Helm release in the next step.

## Uninstall Helm Releases

Uninstall all Helm releases. This will automatically delete all resources created by Helm, including deployments, services, ConfigMaps, and Ingress resources:

```bash
helm uninstall client -n client || true
helm uninstall coprocessor -n apollo || true
for subgraph in checkout discovery inventory orders products reviews shipping users; do
  helm uninstall $subgraph -n $subgraph || true
done
```

## Delete Namespaces

After deleting CRDs and uninstalling Helm releases, delete all application namespaces. This will remove any remaining resources:

```bash
kubectl delete namespace checkout discovery inventory orders products reviews shipping users || true
kubectl delete namespace client || true
kubectl delete secret apollo-api-key -n apollo-operator || true
helm uninstall apollo-operator -n apollo-operator || true
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
minikube stop
minikube delete
```

Or if you have multiple Minikube profiles and want to delete all:

```bash
minikube delete --all
```

## Clean Up Local Docker Images (Optional)

If you want to remove the local Docker images built for this project:

```bash
eval $(minikube docker-env)
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
