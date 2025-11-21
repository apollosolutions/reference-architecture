# Zipkin - Distributed Tracing

Zipkin is deployed as part of the telemetry stack for distributed tracing across the supergraph.

## Overview

Zipkin collects and visualizes distributed traces from:
- Apollo Router (via OpenTelemetry Collector)
- All subgraphs (via OpenTelemetry Collector)

## Architecture

```
Subgraphs (OTLP) ──┐
                   ├──> OTEL Collector ──> Zipkin
Apollo Router (OTLP) ──┘
```

## Deployment

Zipkin is deployed via the telemetry deployment script:

```bash
./scripts/minikube/10-deploy-telemetry.sh
```

This script:
- Creates the `monitoring` namespace
- Deploys Zipkin using Helm
- Waits for Zipkin to be ready

## Configuration

Zipkin is configured with in-memory storage (suitable for development and testing). Configuration is in `values.yaml`:

```yaml
zipkin:
  storage:
    type: mem
```

## Access

### Within Cluster

Zipkin is accessible at:
- Service: `http://zipkin.monitoring.svc.cluster.local:9411`

### From Local Machine

Port-forward to access the Zipkin UI:

```bash
kubectl port-forward -n monitoring svc/zipkin 9411:9411
```

Then open http://localhost:9411 in your browser.

## Integration

- **OTEL Collector**: Receives traces via OTLP and exports to Zipkin
- **Subgraphs**: Send traces to OTEL Collector via `OTEL_HTTP_ENDPOINT` environment variable
- **Apollo Router**: Configured in `router-config.yaml` to send traces to OTEL Collector

## Storage

Currently configured with in-memory storage. Traces are lost when Zipkin restarts. For production use, consider:
- Elasticsearch
- MySQL/PostgreSQL
- Cassandra

See [Zipkin Storage Options](https://zipkin.io/pages/storage.html) for more details.
