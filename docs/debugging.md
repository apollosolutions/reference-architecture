# Debugging Guide

This guide covers common issues and debugging steps for the reference architecture, particularly when using the local OCI registry.

## Table of Contents

- [Registry Setup Issues](#registry-setup-issues)
- [Docker Push/Pull Failures](#docker-pushpull-failures)
- [Operator OCI Registry Access](#operator-oci-registry-access)
- [Schema Not Pushed to Registry](#schema-not-pushed-to-registry)
- [Image Tag Issues](#image-tag-issues)
- [Network and DNS Issues](#network-and-dns-issues)
- [Quick Debug Scripts](#quick-debug-scripts)

## Registry Setup Issues

### Registry Not Accessible

**Symptoms:**
- `curl` commands hang or timeout
- `docker push` fails with connection errors
- Operator can't fetch schemas

**Debug Steps:**

1. **Check if registry service exists:**
   ```bash
   kubectl get svc registry -n kube-system
   ```

2. **Verify registry pod is running:**
   ```bash
   kubectl get pods -n kube-system -l kubernetes.io/minikube-addons=registry
   kubectl logs -n kube-system -l kubernetes.io/minikube-addons=registry --tail=50
   ```

3. **Test registry accessibility from within cluster:**
   ```bash
   kubectl run registry-test --image=curlimages/curl --rm -it --restart=Never --namespace=kube-system --timeout=30s -- \
     curl -s --max-time 10 http://registry.kube-system.svc.cluster.local:80/v2/
   ```

4. **Check registry port (may be dynamic with docker driver):**
   ```bash
   kubectl get svc registry -n kube-system -o jsonpath='{.spec.ports[?(@.name=="http")].port}'
   ```

**Common Issues:**
- Registry addon not enabled: Run `minikube addons enable registry`
- Wrong port: Minikube with docker driver may use a dynamic port (e.g., 64845) instead of 80
- Registry still initializing: Wait a few seconds and retry

### Port Detection Issues

**Symptoms:**
- Scripts fail with "Could not determine registry port"
- Wrong port being used

**Debug Steps:**

1. **Check actual registry service ports:**
   ```bash
   kubectl get svc registry -n kube-system -o yaml | grep -A 5 ports
   ```

2. **Verify script is getting HTTP port (not HTTPS):**
   ```bash
   # Should return 80 (or dynamic port)
   kubectl get svc registry -n kube-system -o jsonpath='{.spec.ports[?(@.name=="http")].port}'
   ```

3. **Check if port is null or empty:**
   ```bash
   PORT=$(kubectl get svc registry -n kube-system -o jsonpath='{.spec.ports[?(@.name=="http")].port}')
   echo "Port: '${PORT}'"
   ```

**Solution:**
- Ensure scripts use `{.spec.ports[?(@.name=="http")].port}` to get HTTP port specifically
- Don't fall back to default port 5000 - error if port can't be determined

## Docker Push/Pull Failures

### HTTPS Client Error

**Symptoms:**
```
Get "https://192.168.49.2:80/v2/": http: server gave HTTP response to HTTPS client
```

**Cause:** Docker is trying to use HTTPS but the registry is HTTP-only.

**Debug Steps:**

1. **Check Docker insecure registries configuration:**
   ```bash
   minikube ssh "docker info 2>/dev/null | grep -A 10 'Insecure Registries'"
   ```

2. **Verify ClusterIP is in insecure registry range:**
   ```bash
   REGISTRY_IP=$(kubectl get svc registry -n kube-system -o jsonpath='{.spec.clusterIP}')
   echo "Registry ClusterIP: ${REGISTRY_IP}"
   # Should be in 10.96.0.0/12 range (default insecure registry range)
   ```

3. **Check if using ClusterIP vs Minikube IP:**
   - When using `minikube docker-env`, Docker runs inside Minikube VM
   - Use ClusterIP (e.g., `10.110.93.31:80`) not Minikube IP (e.g., `192.168.49.2:80`)
   - ClusterIP is already in Docker's insecure registry range

**Solution:**
- Use ClusterIP for Docker pushes when using `minikube docker-env`
- ClusterIP is in `10.96.0.0/12` which is already configured as insecure
- No need for `--insecure-registry` flag when using ClusterIP

### Connection Refused

**Symptoms:**
```
dial tcp 192.168.49.2:80: connect: connection refused
```

**Debug Steps:**

1. **Verify registry is accessible from Minikube:**
   ```bash
   minikube ssh "curl -s --max-time 5 http://$(kubectl get svc registry -n kube-system -o jsonpath='{.spec.clusterIP}'):80/v2/"
   ```

2. **Check if using correct IP and port:**
   ```bash
   REGISTRY_IP=$(kubectl get svc registry -n kube-system -o jsonpath='{.spec.clusterIP}')
   REGISTRY_PORT=$(kubectl get svc registry -n kube-system -o jsonpath='{.spec.ports[?(@.name=="http")].port}')
   echo "Using: ${REGISTRY_IP}:${REGISTRY_PORT}"
   ```

**Solution:**
- Use ClusterIP, not Minikube IP, when Docker is running inside Minikube VM
- Verify port is correct (may be dynamic with docker driver)

## Operator OCI Registry Access

### Operator Can't Fetch Schema from Registry

**Symptoms:**
- Operator logs show: `error fetching OCI image: oci error: error sending request`
- Subgraph or Supergraph status shows schema loading errors

**Debug Steps:**

1. **Check operator logs for OCI errors:**
   ```bash
   kubectl logs -n apollo-operator deployment/apollo-operator --tail=100 | grep -i "oci\|registry\|error"
   ```

2. **Verify operator configuration:**
   ```bash
   kubectl get configmap apollo-operator-config -n apollo-operator -o yaml | grep -A 10 http_only_registries
   ```

   Should show both:
   - Service DNS: `registry.kube-system.svc.cluster.local:80`
   - ClusterIP: `10.110.93.31:80` (your actual ClusterIP)

3. **Test registry access from operator pod:**
   ```bash
   OPERATOR_POD=$(kubectl get pods -n apollo-operator -l app.kubernetes.io/name=apollo-operator -o jsonpath='{.items[0].metadata.name}')
   
   # Test service DNS
   kubectl exec -n apollo-operator $OPERATOR_POD -- curl -s --max-time 10 http://registry.kube-system.svc.cluster.local:80/v2/_catalog | jq '.repositories' 2>/dev/null || echo "Failed"
   
   # Test ClusterIP
   REGISTRY_IP=$(kubectl get svc registry -n kube-system -o jsonpath='{.spec.clusterIP}')
   kubectl exec -n apollo-operator $OPERATOR_POD -- curl -s --max-time 10 http://${REGISTRY_IP}:80/v2/_catalog | jq '.repositories' 2>/dev/null || echo "Failed"
   ```

4. **Check Subgraph/Supergraph CRD for registry reference:**
   ```bash
   # Check Subgraph
   kubectl get subgraph products -n products -o jsonpath='{.spec.schema.ociImage.reference}'
   
   # Check Supergraph
   kubectl get supergraph reference-architecture-dev -n apollo -o jsonpath='{.spec.schema.oci.reference}'
   ```

**Common Issues:**
- **HTTPS errors**: Operator trying HTTPS when registry is HTTP-only
  - Solution: Ensure `http_only_registries` is configured in operator values
  - Check both service DNS and ClusterIP are in the list
  
- **DNS resolution**: Operator can't resolve service DNS
  - Solution: Use ClusterIP in CRDs instead of service DNS
  - Scripts should replace service DNS with ClusterIP dynamically

- **Wrong port**: Using port 5000 instead of 80
  - Solution: Scripts should detect HTTP port dynamically
  - Minikube registry addon uses port 80 (or dynamic port with docker driver)

### Operator Configuration Issues

**Symptoms:**
- `http_only_registries` not in operator config
- Operator still trying HTTPS

**Debug Steps:**

1. **Check operator ConfigMap:**
   ```bash
   kubectl get configmap apollo-operator-config -n apollo-operator -o yaml
   ```

2. **Verify YAML structure:**
   ```bash
   kubectl get configmap apollo-operator-config -n apollo-operator -o jsonpath='{.data.config\.yaml}' | grep -A 5 oci
   ```

   Should show:
   ```yaml
   oci:
     http_only_registries:
       - "registry.kube-system.svc.cluster.local:80"
       - "10.110.93.31:80"
   ```

3. **Check if operator was upgraded after registry setup:**
   ```bash
   # Re-run registry setup to update operator
   ./scripts/minikube/03a-setup-registry.sh
   ```

**Solution:**
- Ensure `http_only_registries` is under `config.oci` (not directly under `config`)
- Both service DNS and ClusterIP should be in the list
- Use snake_case: `http_only_registries` (not `httpOnlyRegistries`)

## Schema Not Pushed to Registry

### Supergraph Schema Not Appearing in Registry

**Symptoms:**
- `supergraph-schema` repository not in registry catalog
- No tags for `supergraph-schema` in registry

**Debug Steps:**

1. **Check if SupergraphSchema composition succeeded:**
   ```bash
   kubectl get supergraphschema reference-architecture-dev -n apollo -o yaml
   kubectl describe supergraphschema reference-architecture-dev -n apollo
   ```

   Look for:
   - `Available: True` condition
   - `CompositionPending: False`
   - Launch ID in status

2. **Check Supergraph status:**
   ```bash
   kubectl get supergraph reference-architecture-dev -n apollo -o yaml
   kubectl describe supergraph reference-architecture-dev -n apollo
   ```

   Look for:
   - `SchemaLoaded: True` condition
   - Status messages about schema fetching

3. **Check operator logs for push errors:**
   ```bash
   kubectl logs -n apollo-operator deployment/apollo-operator --tail=200 | grep -i "push\|oci\|schema.*registry"
   ```

4. **Verify Supergraph CRD has OCI reference:**
   ```bash
   kubectl get supergraph reference-architecture-dev -n apollo -o jsonpath='{.spec.schema.oci.reference}'
   ```

   Should show something like: `10.110.93.31:80/supergraph-schema:1734220800`

5. **Check what's actually in the registry:**
   ```bash
   # List all repositories
   CATALOG_OUTPUT=$(kubectl run registry-catalog --image=curlimages/curl --rm -i --restart=Never --namespace=kube-system --timeout=30s -- \
     sh -c 'curl -s http://registry.kube-system.svc.cluster.local:80/v2/_catalog 2>/dev/null' 2>&1 | grep -v "^pod/" | grep -v "deleted from")
   CATALOG=$(echo "$CATALOG_OUTPUT" | grep -E '^\{|^\[' | head -n 1)
   if [ -n "$CATALOG" ] && echo "$CATALOG" | jq -e '.repositories' >/dev/null 2>&1; then
     echo "$CATALOG" | jq -r '.repositories[]'
   else
     echo "Could not parse catalog"
   fi
   
   # Check supergraph-schema tags
   TAGS_OUTPUT=$(kubectl run registry-tags --image=curlimages/curl --rm -i --restart=Never --namespace=kube-system --timeout=30s -- \
     sh -c 'curl -s http://registry.kube-system.svc.cluster.local:80/v2/supergraph-schema/tags/list 2>/dev/null' 2>&1 | grep -v "^pod/" | grep -v "deleted from")
   TAGS=$(echo "$TAGS_OUTPUT" | grep -E '^\{|^\[' | head -n 1)
   if [ -n "$TAGS" ] && echo "$TAGS" | jq -e '.tags' >/dev/null 2>&1; then
     echo "$TAGS" | jq -r '.tags[]'
   else
     echo "Could not parse tags or repository does not exist"
   fi
   ```

**Common Issues:**
- **Composition not complete**: SupergraphSchema hasn't composed yet
  - Solution: Wait for composition, check SupergraphSchema status
  
- **Wrong registry reference**: CRD pointing to wrong registry or tag
  - Solution: Verify the reference matches actual registry location
  
- **Operator can't push**: Network or authentication issues
  - Solution: Check operator logs, verify registry accessibility from operator pod

### Subgraph Schema Not in Image

**Symptoms:**
- Subgraph status shows schema extraction errors
- Operator can't find schema in OCI image

**Debug Steps:**

1. **Check Subgraph status:**
   ```bash
   kubectl describe subgraph products -n products
   ```

   Look for `SchemaLoaded` condition and error messages

2. **Verify schema path in Subgraph CRD:**
   ```bash
   kubectl get subgraph products -n products -o jsonpath='{.spec.schema.ociImage.path}'
   ```

   Should be: `/usr/src/app/schema.graphql`

3. **Check if image actually contains schema:**
   ```bash
   # Get image reference
   IMAGE=$(kubectl get subgraph products -n products -o jsonpath='{.spec.schema.ociImage.reference}')
   
   # Inspect image (if accessible)
   docker pull $IMAGE
   docker run --rm $IMAGE cat /usr/src/app/schema.graphql
   ```

**Solution:**
- Ensure schema path matches where schema is in Docker image
- Verify image was built with schema file included
- Check Dockerfile copies schema to correct location

## Image Tag Issues

### Tag Validation Failures

**Symptoms:**
- Scripts fail with "Invalid image tag"
- Tag too short or empty

**Debug Steps:**

1. **Check .image-tag file:**
   ```bash
   cat .image-tag
   ```

2. **Verify tag format:**
   ```bash
   TAG=$(cat .image-tag)
   echo "Tag length: ${#TAG}"
   echo "Tag value: '${TAG}'"
   ```

3. **Check what scripts expect:**
   - Unix timestamp: 10 digits (e.g., `1734220800`)
   - Minimum length: 8 characters

**Solution:**
- Ensure `.image-tag` file exists and contains valid tag
- Re-run `04-build-images.sh` to regenerate tag if needed

## Network and DNS Issues

### DNS Resolution Failures

**Symptoms:**
```
dial tcp: lookup registry.kube-system.svc.cluster.local on 192.168.65.254:53: server misbehaving
```

**Cause:** Kubelet or Docker daemon using host DNS instead of Kubernetes CoreDNS

**Debug Steps:**

1. **Check which DNS resolver is being used:**
   ```bash
   minikube ssh "cat /etc/resolv.conf"
   ```

2. **Test DNS resolution from pod:**
   ```bash
   kubectl run dns-test --image=busybox --rm -it --restart=Never -- \
     nslookup registry.kube-system.svc.cluster.local
   ```

3. **Test DNS resolution from Minikube node:**
   ```bash
   minikube ssh "nslookup registry.kube-system.svc.cluster.local"
   ```

**Solution:**
- Use ClusterIP instead of service DNS for kubelet (image pulls)
- Use ClusterIP instead of service DNS for Docker daemon (when using minikube docker-env)
- Service DNS works fine from Kubernetes pods (operator can use it)

### Service DNS vs ClusterIP

**When to use which:**

| Context | Use | Why |
|---------|-----|-----|
| Kubernetes pods (operator) | Service DNS or ClusterIP | Both work, pods can resolve service DNS |
| Kubelet (image pulls) | ClusterIP | Kubelet may use host DNS which can't resolve service DNS |
| Docker daemon (minikube docker-env) | ClusterIP | Docker in Minikube VM may not resolve service DNS |
| Host Docker (not minikube docker-env) | Minikube IP + port-forward | Requires socat or port-forward |

## Quick Debug Scripts

### Complete Registry Debug

```bash
#!/bin/bash
echo "=== Registry Service ==="
kubectl get svc registry -n kube-system

echo ""
echo "=== Registry Pod ==="
kubectl get pods -n kube-system -l kubernetes.io/minikube-addons=registry

echo ""
echo "=== Registry Ports ==="
kubectl get svc registry -n kube-system -o jsonpath='HTTP: {.spec.ports[?(@.name=="http")].port}{"\n"}HTTPS: {.spec.ports[?(@.name=="https")].port}{"\n"}'

echo ""
echo "=== Registry ClusterIP ==="
kubectl get svc registry -n kube-system -o jsonpath='{.spec.clusterIP}'
echo ""

echo ""
echo "=== Registry Accessibility (from pod) ==="
kubectl run registry-test --image=curlimages/curl --rm -i --restart=Never --namespace=kube-system --timeout=30s -- \
  curl -s --max-time 10 http://registry.kube-system.svc.cluster.local:80/v2/ 2>/dev/null | grep -v "^pod/" || echo "Failed"

echo ""
echo "=== Registry Catalog ==="
CATALOG_OUTPUT=$(kubectl run registry-catalog --image=curlimages/curl --rm -i --restart=Never --namespace=kube-system --timeout=30s -- \
  sh -c 'curl -s http://registry.kube-system.svc.cluster.local:80/v2/_catalog 2>/dev/null' 2>&1 | grep -v "^pod/" | grep -v "deleted from")
# Extract JSON by finding lines that look like JSON (start with { or [)
CATALOG=$(echo "$CATALOG_OUTPUT" | grep -E '^\{|^\[' | head -n 1)
if [ -n "$CATALOG" ] && echo "$CATALOG" | jq -e '.repositories' >/dev/null 2>&1; then
  echo "$CATALOG" | jq -r '.repositories[]'
else
  echo "Could not access or parse catalog"
  echo "Debug: First 200 chars of output: ${CATALOG_OUTPUT:0:200}"
fi
```

### Operator OCI Debug

```bash
#!/bin/bash
echo "=== Operator Config (OCI) ==="
kubectl get configmap apollo-operator-config -n apollo-operator -o jsonpath='{.data.config\.yaml}' | grep -A 10 oci

echo ""
echo "=== Operator Logs (OCI/Registry) ==="
kubectl logs -n apollo-operator deployment/apollo-operator --tail=50 | grep -i "oci\|registry\|push" || echo "No OCI/registry logs"

echo ""
echo "=== Supergraph Status ==="
kubectl get supergraph reference-architecture-dev -n apollo -o jsonpath='{range .status.conditions[*]}{.type}: {.status}{"\n"}{end}'

echo ""
echo "=== Supergraph OCI Reference ==="
kubectl get supergraph reference-architecture-dev -n apollo -o jsonpath='{.spec.schema.oci.reference}'
echo ""

echo ""
echo "=== SupergraphSchema Status ==="
kubectl get supergraphschema reference-architecture-dev -n apollo -o jsonpath='{range .status.conditions[*]}{.type}: {.status}{"\n"}{end}'
```

### Docker Push Debug

```bash
#!/bin/bash
echo "=== Docker Info (Insecure Registries) ==="
minikube ssh "docker info 2>/dev/null | grep -A 10 'Insecure Registries'" || echo "Could not get Docker info"

echo ""
echo "=== Registry ClusterIP ==="
REGISTRY_IP=$(kubectl get svc registry -n kube-system -o jsonpath='{.spec.clusterIP}')
REGISTRY_PORT=$(kubectl get svc registry -n kube-system -o jsonpath='{.spec.ports[?(@.name=="http")].port}')
echo "Registry: ${REGISTRY_IP}:${REGISTRY_PORT}"

echo ""
echo "=== Test Registry from Minikube ==="
minikube ssh "curl -s --max-time 5 http://${REGISTRY_IP}:${REGISTRY_PORT}/v2/" || echo "Failed"

echo ""
echo "=== Current Image Tag ==="
cat .image-tag 2>/dev/null || echo ".image-tag file not found"
```

## Common Error Messages and Solutions

### `http: server gave HTTP response to HTTPS client`
**Cause:** Docker trying HTTPS on HTTP-only registry  
**Solution:** Use ClusterIP (in insecure registry range) instead of Minikube IP

### `dial tcp: lookup registry.kube-system.svc.cluster.local on 192.168.65.254:53: server misbehaving`
**Cause:** DNS resolution failure (using host DNS instead of CoreDNS)  
**Solution:** Use ClusterIP instead of service DNS

### `Could not determine registry port`
**Cause:** Registry service not found or port query failed  
**Solution:** Ensure registry addon is enabled, check service exists

### `error fetching OCI image: oci error: error sending request`
**Cause:** Operator can't access registry (network, DNS, or HTTPS issue)  
**Solution:** 
- Check `http_only_registries` configuration
- Verify registry accessibility from operator pod
- Use ClusterIP in CRDs if DNS resolution fails

### `Invalid image tag`
**Cause:** Tag in `.image-tag` is empty or too short  
**Solution:** Re-run `04-build-images.sh` to regenerate tag

## Getting Help

If you're still stuck after trying these debugging steps:

1. **Collect logs:**
   ```bash
   kubectl logs -n apollo-operator deployment/apollo-operator > operator.log
   kubectl describe supergraph reference-architecture-dev -n apollo > supergraph-status.txt
   kubectl get svc registry -n kube-system -o yaml > registry-service.yaml
   ```

2. **Check operator version:**
   ```bash
   kubectl get deployment apollo-operator -n apollo-operator -o jsonpath='{.spec.template.spec.containers[0].image}'
   ```

3. **Verify environment:**
   ```bash
   echo "USE_LOCAL_REGISTRY: ${USE_LOCAL_REGISTRY:-not set}"
   echo "ENVIRONMENT: ${ENVIRONMENT:-not set}"
   minikube status
   ```

