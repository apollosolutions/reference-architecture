# Pattern B — private registry with imagePullSecrets

Use this pattern when **your cluster can reach a private registry**
(Harbor, JFrog Artifactory, AWS ECR, internal Nexus, etc.) but cannot pull
from the public `ghcr.io`. The chart itself is still installed by pointing
`helm` at a one-time tarball, but the image is pulled from your private
registry using credentials managed via a Kubernetes secret.

## Steps

```bash
# 1. Create the docker-registry secret in the target namespace
kubectl create namespace apollo --dry-run=client -o yaml | kubectl apply -f -

kubectl -n apollo create secret docker-registry regcred \
  --docker-server=registry.example.com \
  --docker-username='<bot user>' \
  --docker-password='<bot token>' \
  --docker-email='infra@example.com'

# 2. Mirror the Router image into registry.example.com (see ../README.md)

# 3. Install — chart fetched from the OCI registry once, vendored locally
helm pull oci://ghcr.io/apollographql/helm-charts/router --version 1.71.0 -d ./vendor
helm upgrade --install router ./vendor/router-1.71.0.tgz \
  -f values.yaml \
  -n apollo
```

If your CI / control-plane host _also_ can't reach `oci://ghcr.io/...`, swap
step 3 for a checked-in tarball as in [Pattern A](../pattern-a-local-chart).

## Files

- [`values.yaml`](values.yaml) — annotated values pointing at the private
  registry with `imagePullSecrets` wired up.
- [`regcred.example.yaml`](regcred.example.yaml) — declarative form of the
  secret for GitOps tools (Argo CD, Flux). **Do not commit real credentials.**

## Verifying

```bash
kubectl -n apollo get pods -l app.kubernetes.io/name=router \
  -o jsonpath='{.items[0].spec.containers[0].image}'
# expected: registry.example.com/apollo/router:v2.10.0

kubectl -n apollo describe pod -l app.kubernetes.io/name=router \
  | grep -E 'Image:|ImagePullSecrets:'
```
