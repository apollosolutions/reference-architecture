# Apollo Router Helm — non-OCI registry examples

The official Apollo Router Helm chart is distributed as an [OCI artifact](https://helm.sh/docs/topics/registries/)
on `oci://ghcr.io/apollographql/helm-charts/router`, and pulls the Router
container image from the same OCI registry. Some customers run in environments
where their cluster (or their CI runner) cannot reach OCI artifact registries
— typically because the platform team only allows traditional `https://`
Helm chart repositories and image registries.

This directory contains two working patterns for those environments. **Both
patterns use the same Router image** — that image is just a regular OCI image
hosted on GHCR; what changes is _how_ you obtain the chart and _which registry_
the cluster pulls the image from.

| Pattern | Chart source | Image registry | Use when… |
| --- | --- | --- | --- |
| [`pattern-a-local-chart`](pattern-a-local-chart) | Local chart copy (git or tarball) | Your own Docker Hub / ECR / GCR / Harbor mirror | Cluster has no outbound OCI access; you mirror images into a private registry. |
| [`pattern-b-private-registry`](pattern-b-private-registry) | Helm pull + values override | Private registry with `imagePullSecrets` | Cluster can fetch from a private registry that requires credentials. |

> [!NOTE]
> These examples target **Apollo Router 2.x** (chart `1.x`). Update the `image.tag` /
> chart version pins to match your target Router release.

## Mirror the image first

Both patterns assume the Router image has been mirrored into the registry the
cluster _can_ reach. The official image is published at
`ghcr.io/apollographql/router:v2.10.0`. Typical mirror flow:

```bash
ROUTER_VERSION=v2.10.0

# pull from upstream (run from a host with internet access)
docker pull ghcr.io/apollographql/router:${ROUTER_VERSION}

# re-tag and push to your registry of choice
docker tag ghcr.io/apollographql/router:${ROUTER_VERSION} \
  registry.example.com/apollo/router:${ROUTER_VERSION}
docker push registry.example.com/apollo/router:${ROUTER_VERSION}
```

Once the image is in your registry, point `image.repository` and `image.tag` at
it in the values file (see the per-pattern READMEs).

## See also

- Upstream chart README: <https://github.com/apollographql/router/tree/dev/helm/chart/router>
- Apollo Router image releases: <https://github.com/apollographql/router/releases>
- Router on Kubernetes docs: <https://www.apollographql.com/docs/router/containerization/kubernetes>
