# Pattern A — vendored chart + mirrored image

Use this pattern when **the cluster has no outbound OCI access at all**. You
vendor the chart files into your own repo (or fetch the tarball once from a
machine that _does_ have access) and reference a non-OCI image registry mirror.

## Steps

```bash
# 1. One-time: pull the chart tarball from a host with OCI access and commit it
helm pull oci://ghcr.io/apollographql/helm-charts/router \
  --version 1.71.0 \
  --destination ./vendor
# yields ./vendor/router-1.71.0.tgz

# 2. Mirror the Router image into your registry (see ../README.md)

# 3. Install from the local tarball, overriding image source
helm upgrade --install router ./vendor/router-1.71.0.tgz \
  -f values.yaml \
  -n apollo --create-namespace
```

## Files

- [`values.yaml`](values.yaml) — annotated values for a non-OCI deployment.

## Verifying the rendered manifests

Before applying to a real cluster, render and inspect:

```bash
helm template router ./vendor/router-1.71.0.tgz -f values.yaml \
  | grep -E 'image:|imagePullSecrets:'
```

You should see `image: registry.example.com/apollo/router:v2.10.0` — not the
`ghcr.io/apollographql/...` default.
