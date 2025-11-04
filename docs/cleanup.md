## Cleanup

⏱ Estimated time: 15 minutes

Running Google Cloud or AWS resources will continue to incur costs on your account so we have documented all the steps to take for a proper tear-down.

### Automated cleanup

### Delete Operator-Managed Resources

Before deleting Kubernetes resources, first remove the operator-managed CRDs. **The following steps are provided for both dev and prod clusters:**

```sh
# Start with dev cluster
kubectx apollo-supergraph-k8s-dev

# Delete Supergraph resources (this deletes the router deployment)
kubectl delete supergraphs reference-architecture-dev -n apollo

# Delete SupergraphSchema resources
kubectl delete supergraphschemas reference-architecture-dev -n apollo

# Delete Ingress resources for the router
kubectl delete ingress router -n apollo || true

# Delete Subgraph resources (this will also stop schema publishing)
kubectl delete subgraph --all --all-namespaces

# Uninstall Helm releases
helm uninstall coprocessor -n apollo
helm uninstall client -n client

# Uninstall subgraph Helm releases before deleting namespaces
for subgraph in checkout discovery inventory orders products reviews shipping users; do
  helm uninstall $subgraph -n $subgraph || true
done

# Delete subgraph namespaces (each subgraph has its own namespace)
kubectl delete namespace checkout discovery inventory orders products reviews shipping users

# Delete client namespace
kubectl delete namespace client

# Delete operator API key secret (contains sensitive data)
# Note: Helm release secrets (sh.helm.release.v1.*) are automatically cleaned up by helm uninstall
kubectl delete secret apollo-api-key -n apollo-operator || true

# Uninstall the Apollo GraphOS Operator
# This will also automatically clean up Helm release secrets (sh.helm.release.v1.*)
helm uninstall apollo-operator -n apollo-operator

# Delete operator namespaces
kubectl delete namespace apollo-operator apollo

# Repeat for prod cluster
kubectx apollo-supergraph-k8s-prod

kubectl delete supergraphs reference-architecture-prod -n apollo
kubectl delete supergraphschemas reference-architecture-prod -n apollo
kubectl delete ingress router -n apollo || true
kubectl delete subgraph --all --all-namespaces
helm uninstall coprocessor -n apollo
helm uninstall client -n client

# Uninstall subgraph Helm releases before deleting namespaces
for subgraph in checkout discovery inventory orders products reviews shipping users; do
  helm uninstall $subgraph -n $subgraph || true
done

kubectl delete namespace checkout discovery inventory orders products reviews shipping users
kubectl delete namespace client

# Delete operator API key secret (contains sensitive data)
# Note: Helm release secrets (sh.helm.release.v1.*) are automatically cleaned up by helm uninstall
kubectl delete secret apollo-api-key -n apollo-operator || true

# Uninstall the Apollo GraphOS Operator
# This will also automatically clean up Helm release secrets (sh.helm.release.v1.*)
helm uninstall apollo-operator -n apollo-operator
kubectl delete namespace apollo-operator apollo
```

### Cloud-specific steps

There are a few cloud-specific steps you'll need to take.

#### <image src="../images/gcp.svg" height="13" style="margin:auto;" /> GCP

**Clean up GCP Workload Identity bindings** (created during setup for monitoring):

```sh
# You'll need your PROJECT_ID and CLUSTER_PREFIX (default: apollo-supergraph-k8s)
CLUSTER_PREFIX=${CLUSTER_PREFIX:-"apollo-supergraph-k8s"}
PROJECT_ID="<your-gcp-project-id>"

# Remove workload identity binding (shared across dev and prod clusters)
# Note: This only needs to be run once, not per cluster
gcloud iam service-accounts remove-iam-policy-binding \
  "${CLUSTER_PREFIX:0:12}-metrics-writer@$PROJECT_ID.iam.gserviceaccount.com" \
  --role roles/iam.workloadIdentityUser \
  --member "serviceAccount:${PROJECT_ID}.svc.id.goog[monitoring/metrics-writer]" || true
```

**Note:** The GCP IAM service account `${CLUSTER_PREFIX:0:12}-metrics-writer@$PROJECT_ID.iam.gserviceaccount.com` may be created by Terraform. If it's not removed by `terraform destroy`, you can delete it manually:

```sh
gcloud iam service-accounts delete "${CLUSTER_PREFIX:0:12}-metrics-writer@$PROJECT_ID.iam.gserviceaccount.com" || true
```

In order to delete some non-Kubernetes resources created by Google Cloud, it's easiest to just delete everything:

```sh
kubectx apollo-supergraph-k8s-dev
kubectl delete daemonsets,replicasets,services,deployments,pods,rc,ingress --all --all-namespaces
```

The command may hang at the end. You can kill the process (`ctrl-c`) and repeat with the prod cluster:

```sh
kubectx apollo-supergraph-k8s-prod
kubectl delete daemonsets,replicasets,services,deployments,pods,rc,ingress --all --all-namespaces
```

#### <image src="../images/aws.svg" height="13" style="margin:auto;" /> AWS

In order to ensure the load balancers are properly removed, and the IAM service roles are removed, run the following, replacing `apollo-supergraph-k8s` with the appropriate cluster prefix if modified: 

```sh
# dev
eksctl delete iamserviceaccount \
    --cluster=apollo-supergraph-k8s-dev \
    --name="aws-load-balancer-controller" 
aws cloudformation delete-stack --stack-name eksctl-apollo-supergraph-k8s-dev-addon-iamserviceaccount-kube-system-aws-load-balancer-controller
# prod
eksctl delete iamserviceaccount \
    --cluster=apollo-supergraph-k8s-prod \
    --name="aws-load-balancer-controller" 
aws cloudformation delete-stack --stack-name eksctl-apollo-supergraph-k8s-prod-addon-iamserviceaccount-kube-system-aws-load-balancer-controller
```

### Delete Monitoring Resources

The monitoring namespace may contain additional resources (InfluxDB, Grafana, Zipkin, etc.) that should be cleaned up. **Repeat these steps for both dev and prod clusters:**

```sh
# Start with dev cluster
kubectx apollo-supergraph-k8s-dev

# Uninstall monitoring components (if deployed)
helm uninstall influxdb -n monitoring || true
helm uninstall grafana -n monitoring || true
helm uninstall otel-collector -n monitoring || true
helm uninstall zipkin -n zipkin || true

# Delete monitoring namespaces
kubectl delete namespace monitoring zipkin || true

# Repeat for prod cluster
kubectx apollo-supergraph-k8s-prod

helm uninstall influxdb -n monitoring || true
helm uninstall grafana -n monitoring || true
helm uninstall otel-collector -n monitoring || true
helm uninstall zipkin -n zipkin || true
kubectl delete namespace monitoring zipkin || true
```

### Remaining steps

Then you can destroy all the provisioned resources (Kubernetes clusters, GitHub repositories) with terraform:

```sh
cd terraform/<cloud_provider>
terraform destroy # takes roughly 10 minutes
```

Lastly, you can remove the contexts from your `kubectl`:

```sh
kubectl config delete-context apollo-supergraph-k8s-dev
kubectl config delete-context apollo-supergraph-k8s-prod
```

Terraform does not delete the Docker containers from GitHub. Visit `https://github.com/<your github username>?tab=packages` and delete the packages created by the previous versions of the repos.
