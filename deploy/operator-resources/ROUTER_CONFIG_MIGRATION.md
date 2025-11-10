# Router Configuration TODO List

This document tracks the migration of router configuration from Helm values to operator-managed Supergraph CRDs and the current implementation status.

## ✅ Completed Tasks

- [x] **Graph Creation**: Graph created in Apollo GraphOS
- [x] **Environment Variants**: Dev and prod variants created
- [x] **Subgraphs Deployment**: All subgraphs deployed with CRDs using inline SDL
- [x] **Operator Installation**: Apollo GraphOS Operator installed and configured
- [x] **Router Configuration ConfigMap**: Created `router-config` ConfigMap with custom router settings
- [x] **Rhai Scripts ConfigMap**: Created `rhai-scripts` ConfigMap with logging scripts
- [x] **Router Deployment Patching**: Implemented script to patch router deployment with ConfigMap volumes and args
- [x] **Coprocessor Deployment**: Coprocessor deployed and configured for JWT authentication
- [x] **Router Log Level**: Set to debug via `--log=debug` argument
- [x] **Ingress Configuration**: Ingress set up for external access via minikube tunnel
- [x] **Client Application**: Client deployed with nginx proxying GraphQL requests

## 🔄 Current Implementation Status

### Router Configuration Method

The router configuration is currently implemented using a **hybrid approach**:

1. **Supergraph CRD**: Managed by Apollo GraphOS Operator
   - Schema composition and publishing
   - Basic deployment configuration (replicas, resources, version)
   - Schema source reference

2. **ConfigMap + Manual Patching**: Custom router configuration
   - Router configuration YAML (`router-config.yaml`) mounted via ConfigMap
   - Rhai scripts mounted via ConfigMap
   - Deployment patched manually after operator creates it
   - Script: `scripts/minikube/08-apply-router-config.sh`

### Configuration Files

| Configuration | Location | Status |
|--------------|----------|--------|
| Router Config | `deploy/operator-resources/router-config.yaml` | ✅ Implemented via ConfigMap |
| Rhai Scripts | `deploy/operator-resources/rhai/main.rhai` | ✅ Implemented via ConfigMap |
| SupergraphSchema | Created by `07-deploy-operator-resources.sh` | ✅ Operator-managed |
| Supergraph | Created by `07-deploy-operator-resources.sh` | ✅ Operator-managed (patched) |

## 📋 Configuration Details

### Router Configuration (`router-config.yaml`)

Current configuration includes:
- ✅ Supergraph listen port (4000)
- ✅ Introspection enabled
- ✅ Headers propagation
- ✅ JWT authentication (JWKS from users subgraph)
- ✅ Authorization directives enabled
- ✅ CORS (allow any origin)
- ✅ Coprocessor configuration
- ✅ Health check endpoint (8088)
- ✅ Sandbox enabled
- ✅ Rhai scripts configuration

### Rhai Scripts

- ✅ Logging at all router lifecycle stages:
  - RouterService (HTTP request/response)
  - SupergraphService (GraphQL request/response)
  - ExecutionService (Query plan execution)
  - SubgraphService (Subgraph communication)

### Coprocessor

- ✅ Deployed and running
- ✅ Adds "source" header to subgraph requests
- ✅ JWT validation handled by router's built-in authentication plugin

## ⚠️ Known Limitations

### Operator CRD Limitations

The Apollo GraphOS Operator CRD does not natively support:
- ❌ Custom router configuration YAML in Supergraph CRD
- ❌ ConfigMap volumes for router configuration
- ❌ Custom container args (like `--config` and `--log`)
- ❌ Rhai scripts via ConfigMap volumes

**Workaround**: We patch the deployment manually after the operator creates it.

### Current Workarounds

1. **Router Configuration**: 
   - Created as ConfigMap (`router-config`)
   - Mounted via volume at `/etc/router`
   - Referenced via `--config /etc/router/router.yaml` argument
   - Applied via `scripts/minikube/08-apply-router-config.sh`

2. **Rhai Scripts**:
   - Created as ConfigMap (`rhai-scripts`)
   - Mounted via volume at `/etc/rhai`
   - Referenced in router config YAML
   - Applied via `scripts/minikube/08-apply-router-config.sh`

3. **Log Level**:
   - Set via `--log=debug` argument
   - Applied via `scripts/minikube/08-apply-router-config.sh`

## 🔧 Maintenance Tasks

### When Updating Router Configuration

1. Edit `deploy/operator-resources/router-config.yaml`
2. Update the ConfigMap:
   ```bash
   kubectl create configmap router-config \
       --from-file=router.yaml=deploy/operator-resources/router-config.yaml \
       -n apollo --dry-run=client -o yaml | kubectl apply -f -
   ```
3. Restart router deployment:
   ```bash
   kubectl rollout restart deployment/reference-architecture-${ENVIRONMENT} -n apollo
   ```

### When Updating Rhai Scripts

1. Edit `deploy/operator-resources/rhai/main.rhai`
2. Update the ConfigMap:
   ```bash
   kubectl create configmap rhai-scripts \
       --from-file=main.rhai=deploy/operator-resources/rhai/main.rhai \
       -n apollo --dry-run=client -o yaml | kubectl apply -f -
   ```
3. Restart router deployment:
   ```bash
   kubectl rollout restart deployment/reference-architecture-${ENVIRONMENT} -n apollo
   ```

## 🚀 Future Improvements

### Potential Enhancements

- [ ] **Automate ConfigMap Updates**: Create a script to update ConfigMaps and restart deployments
- [ ] **Configuration Validation**: Add validation for router-config.yaml before applying
- [ ] **Environment-Specific Configs**: Support different router configs per environment
- [ ] **Telemetry Configuration**: Add OTLP tracing/metrics configuration (if needed)
- [ ] **Persisted Queries**: Configure persisted queries for production (if needed)
- [ ] **Operator Support**: Monitor Apollo GraphOS Operator updates for native support of:
  - Custom router configuration
  - ConfigMap volumes
  - Container args
  - Rhai scripts

### Documentation Updates Needed

- [ ] Update `docs/setup.md` with router configuration update procedures
- [ ] Add troubleshooting guide for router configuration issues
- [ ] Document the patching approach and why it's necessary

## 🐛 Troubleshooting

### Router Not Picking Up Configuration Changes

1. Verify ConfigMap exists:
   ```bash
   kubectl get configmap router-config -n apollo
   kubectl get configmap rhai-scripts -n apollo
   ```

2. Check volume mounts:
   ```bash
   kubectl describe deployment reference-architecture-${ENVIRONMENT} -n apollo | grep -A 10 "Volumes:"
   kubectl describe pod <router-pod> -n apollo | grep -A 10 "Mounts:"
   ```

3. Verify container args:
   ```bash
   kubectl get deployment reference-architecture-${ENVIRONMENT} -n apollo -o jsonpath='{.spec.template.spec.containers[0].args}'
   ```

4. Check router logs:
   ```bash
   kubectl logs -n apollo deployment/reference-architecture-${ENVIRONMENT} -f
   ```

### Rhai Script Errors

1. Check Rhai script syntax (Rhai doesn't support `in` operator)
2. Verify ConfigMap is mounted at `/etc/rhai`
3. Check router logs for Rhai execution errors
4. Ensure router config references Rhai scripts correctly

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
   kubectl get configmap router-config -n apollo -o yaml | grep coprocessor
   ```

## 📝 Notes

- The manual patching approach is necessary because the Apollo GraphOS Operator CRD doesn't support all router configuration options
- Router configuration changes require restarting the deployment (not just updating ConfigMap)
- The `08-apply-router-config.sh` script handles all patching logic automatically
- Debug logging is enabled by default via `--log=debug` argument
