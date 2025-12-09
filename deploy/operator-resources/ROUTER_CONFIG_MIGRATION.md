# Router Configuration Status

This document tracks the router configuration implementation using the Apollo GraphOS Operator.

## ✅ Completed Tasks

- [x] **Graph Creation**: Graph created in Apollo GraphOS
- [x] **Environment Variants**: Dev and prod variants created
- [x] **Subgraphs Deployment**: All subgraphs deployed with CRDs using inline SDL
- [x] **Operator Installation**: Apollo GraphOS Operator installed and configured
- [x] **Router Configuration**: Router config now handled via `spec.routerConfig` in Supergraph CRD ✅
- [x] **Coprocessor Deployment**: Coprocessor deployed and configured for JWT authentication
- [x] **Router Log Level**: Set via `APOLLO_ROUTER_LOG` environment variable in Supergraph CRD podTemplate
- [x] **Ingress Configuration**: Ingress set up for external access via minikube tunnel
- [x] **Client Application**: Client deployed with nginx proxying GraphQL requests

## 🔄 Current Implementation Status

### Router Configuration Method

The router configuration is now implemented using the **native operator approach**:

1. **Supergraph CRD**: Managed by Apollo GraphOS Operator
   - Schema composition and publishing
   - Basic deployment configuration (replicas, resources, version)
   - Environment variables (e.g., `APOLLO_ROUTER_LOG=debug`)
   - **Router configuration via `spec.routerConfig`** ✅
   - Schema source reference

### Configuration Files

| Configuration | Location | Status |
|--------------|----------|--------|
| Router Config | `deploy/operator-resources/supergraph-{dev\|prod}.yaml` (spec.routerConfig) | ✅ Native operator support |
| SupergraphSchema | Created by `07-deploy-operator-resources.sh` | ✅ Operator-managed |
| Supergraph | Created by `07-deploy-operator-resources.sh` | ✅ Operator-managed |

## 📋 Configuration Details

### Router Configuration (`spec.routerConfig`)

Router configuration is now defined directly in the Supergraph CRD via `spec.routerConfig`. Current configuration includes:

- ✅ Supergraph listen port (4000)
- ✅ Introspection enabled
- ✅ Headers propagation
- ✅ JWT authentication (JWKS from users subgraph)
- ✅ Authorization directives enabled
- ✅ CORS (allow any origin)
- ✅ Coprocessor configuration
- ✅ Health check endpoint (8088)
- ✅ Sandbox enabled
- ✅ Homepage disabled

### Updating Router Configuration

To update router configuration:

1. **Edit the Supergraph resource:**
   ```bash
   # Edit the router configuration
   vim deploy/operator-resources/supergraph-${ENVIRONMENT}.yaml
   ```

2. **Apply the changes:**
   ```bash
   kubectl apply -f deploy/operator-resources/supergraph-${ENVIRONMENT}.yaml
   ```

3. **The operator will automatically:**
   - Update the router deployment with the new configuration
   - Roll out the changes to all router pods
   - No manual patching required!

### Coprocessor

- ✅ Deployed and running
- ✅ Adds "source" header to subgraph requests
- ✅ JWT validation handled by router's built-in authentication plugin

## ✅ Operator CRD Support

The Apollo GraphOS Operator CRD now supports:
- ✅ Custom router configuration YAML via `spec.routerConfig` ✅
- ✅ Environment variables via `podTemplate.env` ✅
- ✅ Basic deployment configuration ✅

## 🔧 Maintenance Tasks

### When Updating Router Configuration

1. Edit `deploy/operator-resources/supergraph-${ENVIRONMENT}.yaml`
2. Update the `spec.routerConfig` section
3. Apply: `kubectl apply -f deploy/operator-resources/supergraph-${ENVIRONMENT}.yaml`
4. The operator handles the rest automatically!

## 🐛 Troubleshooting

### Router Not Picking Up Configuration Changes

1. Verify Supergraph resource has routerConfig:
   ```bash
   kubectl get supergraph reference-architecture-${ENVIRONMENT} -n apollo -o yaml | grep -A 50 routerConfig
   ```

2. Check router deployment status:
   ```bash
   kubectl get deployment reference-architecture-${ENVIRONMENT} -n apollo
   kubectl rollout status deployment/reference-architecture-${ENVIRONMENT} -n apollo
   ```

3. Check router logs:
   ```bash
   kubectl logs -n apollo deployment/reference-architecture-${ENVIRONMENT} -f
   ```

### Coprocessor Issues

1. Verify coprocessor is running:
   ```bash
   kubectl get pods -n apollo -l app.kubernetes.io/name=coprocessor
   ```

2. Check coprocessor service:
   ```bash
   kubectl get svc coprocessor -n apollo
   ```

3. Verify router config has correct coprocessor URL:
   ```bash
   kubectl get supergraph reference-architecture-${ENVIRONMENT} -n apollo -o yaml | grep coprocessor
   ```

## 📝 Notes

- Router configuration is now fully declarative via the Supergraph CRD
- No manual patching required for router configuration
- Configuration changes are automatically applied by the operator
