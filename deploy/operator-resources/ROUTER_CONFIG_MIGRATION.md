# Router Configuration Migration Guide

This document describes how the router configuration from `deploy/router/values.yaml` was migrated to operator-managed Supergraph CRDs.

## Migration Summary

All router configuration has been moved from Helm values (`deploy/router/values.yaml`) into the Supergraph CRD specifications:
- `deploy/operator-resources/supergraph-dev.yaml` (dev environment)
- `deploy/operator-resources/supergraph-prod.yaml` (prod environment)

## Configuration Mapping

### Core Router Settings (Both Dev and Prod)

| Previous Location | New Location | Value |
|-------------------|--------------|-------|
| `router.configuration.health_check` | `spec.podTemplate.router.configuration.health_check` | `listen: 0.0.0.0:8080` |
| `router.configuration.sandbox` | `spec.podTemplate.router.configuration.sandbox` | `enabled: true` |
| `router.configuration.homepage` | `spec.podTemplate.router.configuration.homepage` | `enabled: false` |
| `router.configuration.supergraph` | `spec.podTemplate.router.configuration.supergraph` | `introspection: true` |
| `router.configuration.include_subgraph_errors` | `spec.podTemplate.router.configuration.include_subgraph_errors` | `all: true` |
| `router.configuration.plugins` | `spec.podTemplate.router.configuration.plugins` | `experimental.expose_query_plan: true` |

### Authentication & Authorization

- **JWKS Authentication**: Points to `http://graphql.users.svc.cluster.local:4001/.well-known/jwks.json`
- **Authorization Preview Directives**: Enabled for all subgraphs

### Coprocessor Configuration

- **URL**: `http://coprocessor.coprocessor.svc.cluster.local:8081`
- **Timeout**: 2s
- **Router Request Headers**: Enabled
- **Subgraph Request/Response Headers**: Enabled

### Rhai Scripts

Rhai scripts are handled via ConfigMap and volume mounts:
- **Scripts Location**: `/dist/rhai` (mounted from ConfigMap)
- **Main Script**: `main.rhai`
- **Helper Scripts**: `client_id.rhai`

The ConfigMap must be created separately:
```bash
kubectl create configmap rhai-config --from-file=deploy/router/rhai/ -n apollo
```

### Prod-Only Configuration

The following configurations are only present in `supergraph-prod.yaml`:

#### Persisted Queries

```yaml
persisted_queries:
  enabled: true
  log_unknown: true
  safelist:
    enabled: false
    require_id: false
```

#### Telemetry

- **Apollo Field-Level Instrumentation**: Sampler 0.5
- **OTLP Tracing**: gRPC endpoint `http://collector.monitoring:4317`
- **OTLP Metrics**: gRPC endpoint `http://collector.monitoring:4317`
- **Service Name**: "router"
- **Service Namespace**: "router"

## How to Update Router Configuration

To update router configuration without redeploying subgraphs:

1. Edit the appropriate Supergraph CRD file:
   - Dev: `deploy/operator-resources/supergraph-dev.yaml`
   - Prod: `deploy/operator-resources/supergraph-prod.yaml`

2. Update the `spec.podTemplate.router.configuration` section

3. Apply the changes:
   ```bash
   kubectl apply -f deploy/operator-resources/supergraph-{dev|prod}.yaml
   ```

4. The operator will automatically trigger a router rollover with the new configuration

## Resources

Dev environment uses minimal resources:
- CPU: 100m
- Memory: 256Mi
- Replicas: 1

Prod environment uses production-grade resources:
- CPU: 500m
- Memory: 512Mi
- Replicas: 3

## Differences from Helm Chart

The operator-managed approach differs from the Helm chart in several ways:

1. **No Helm templates**: Configuration is defined in Kubernetes-native CRDs
2. **Automatic rollover**: The operator handles rolling out changes to the router
3. **Declarative**: All configuration is version-controlled in YAML files
4. **Condition-based**: Can monitor router status via `kubectl get supergraph`

## Troubleshooting

### Router not picking up changes

Check the Supergraph status:
```bash
kubectl describe supergraph reference-architecture-{dev|prod} -n apollo
```

Look for:
- `SchemaLoaded`: Should be `True`
- `Progressing`: Shows deployment status
- `Ready`: Should be `True` when fully deployed

### Rhai scripts not working

Verify the ConfigMap exists and is mounted:
```bash
kubectl get configmap rhai-config -n apollo
kubectl describe pod <router-pod> -n apollo | grep rhai-volume
```

### Coprocessor connection issues

Ensure coprocessor is running and accessible:
```bash
kubectl get pods -n coprocessor
kubectl get svc -n coprocessor
```

## Current Configuration Status

The Supergraph CRDs in this repository use a **simplified configuration** that does not include all the advanced router settings from the original Helm chart. This is because the current Apollo GraphOS Operator CRD does not support all configuration fields.

### Supported Configuration
- ✅ Replicas count
- ✅ Router version
- ✅ Resource limits/requests
- ✅ Schema source (SupergraphSchema resource reference)

### Not Currently Supported in Supergraph CRD
- ❌ Custom router configuration (JWKS auth, coprocessor, CORS, etc.)
- ❌ Rhai scripts via ConfigMap volumes
- ❌ Custom ingress configuration
- ❌ Service type customization
- ❌ Telemetry exporters
- ❌ Advanced authentication/authorization

### Operator API Key Setup

The operator requires an **Operator API key** (not a personal API key). To create one:

1. Go to GraphOS Studio
2. Navigate to your graph → Settings → API Keys
3. Create a new API key with "Operator" role
4. Update the `apollo-api-key` secret with the Operator API key:
   ```bash
   kubectl create secret generic apollo-api-key \
     --from-literal="APOLLO_KEY=<your-operator-api-key>" \
     -n apollo-operator \
     --dry-run=client -o yaml | kubectl apply -f -
   ```

### TODO: Advanced Router Configuration

The advanced router configuration (JWKS, coprocessor, Rhai scripts, telemetry, persisted queries) from the original `deploy/router/values.yaml` has not been migrated yet. This would need to be implemented either:

1. Via router configuration YAML file in a ConfigMap (if supported)
2. Through GraphOS Studio router configuration
3. By extending the operator to support these fields
4. By using a custom router deployment instead of the operator-managed one

### Current Status

- Graph is created ✅
- Dev and prod variants created ✅
- Subgraphs deployed and CRDs created ✅
- Operator API key needs to be set up ⚠️
- Advanced router configuration not yet migrated ⏳

