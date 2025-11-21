# OpenTelemetry Collector

The OpenTelemetry Collector receives telemetry data from the Apollo Router and subgraphs, then exports it to Zipkin for visualization.

## Overview

The collector acts as a bridge between instrumented services and Zipkin:
- Receives traces via OTLP (HTTP on port 4318, gRPC on port 4317)
- Processes and batches traces
- Exports to Zipkin

## Architecture

```
Subgraphs (OTLP) ──┐
                   ├──> OTEL Collector ──> Zipkin
Apollo Router (OTLP) ──┘
```

## Deployment

The collector is deployed via the telemetry deployment script:

```bash
./scripts/minikube/10-deploy-telemetry.sh
```

This script:
- Creates the `monitoring` namespace
- Deploys Zipkin first (collector depends on it)
- Deploys the OpenTelemetry Collector using Helm
- Waits for the collector to be ready

## Configuration

The collector configuration is in `templates/configmap.yaml`:

- **Receivers**: OTLP (HTTP on 4318, gRPC on 4317)
- **Processors**: Memory limiter and batch processor
- **Exporters**: Zipkin (http://zipkin.monitoring.svc.cluster.local:9411/api/v2/spans)

## Access

### Within Cluster

The collector is accessible at:
- HTTP: `http://collector.monitoring.svc.cluster.local:4318`
- gRPC: `http://collector.monitoring.svc.cluster.local:4317`

### Endpoints

- **OTLP HTTP**: `/v1/traces` (used by subgraphs and router)
- **OTLP gRPC**: Port 4317 (alternative protocol)

## Integration

### Subgraphs

Subgraphs are configured via the `OTEL_HTTP_ENDPOINT` environment variable:

```yaml
env:
  - name: OTEL_HTTP_ENDPOINT
    value: http://collector.monitoring.svc.cluster.local:4318/v1/traces
```

This is set in:
- `subgraphs/*/deploy/environments/dev.yaml`
- `subgraphs/*/deploy/environments/prod.yaml`

### Apollo Router

The router is configured in `deploy/operator-resources/router-config.yaml`:

```yaml
telemetry:
  exporters:
    tracing:
      otlp:
        enabled: true
        endpoint: http://collector.monitoring.svc.cluster.local:4318
        protocol: http
```

## Monitoring

Check collector status:

```bash
kubectl get pods -n monitoring -l app.kubernetes.io/name=collector
kubectl logs -n monitoring -l app.kubernetes.io/name=collector
```

## Troubleshooting

If traces are not appearing in Zipkin:

1. **Check collector is running:**
   ```bash
   kubectl get pods -n monitoring
   ```

2. **Check collector logs:**
   ```bash
   kubectl logs -n monitoring -l app.kubernetes.io/name=collector
   ```

3. **Verify Zipkin is accessible:**
   ```bash
   kubectl get svc zipkin -n monitoring
   ```

4. **Check subgraph environment variables:**
   ```bash
   kubectl get deployment <subgraph> -n <namespace> -o yaml | grep OTEL_HTTP_ENDPOINT
   ```
