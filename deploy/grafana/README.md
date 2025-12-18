# Grafana Configuration

This directory contains Grafana configuration files for visualizing Apollo Router metrics.

## Files

- `values.yaml` - Helm values file for Grafana deployment
- `graphos-template.json` - GraphOS Runtime Dashboard Template for monitoring Apollo Router metrics

## Deployment

Grafana is deployed via `scripts/minikube/10-deploy-telemetry.sh`, which:
- Creates a ConfigMap from `graphos-template.json`
- Labels it with `grafana_dashboard=1` so the Grafana sidecar automatically loads it
- Deploys Grafana using the Helm chart with Prometheus datasource configured

## Dashboard

The `graphos-template.json` dashboard includes:
- Request traffic and health metrics
- Error rates and codes
- Latency percentiles
- Subgraph metrics
- Coprocessor metrics
- Query planning metrics
- Cache metrics

Dashboard variables:
- `job_name` - Filter by job label (default: "router")
- `otel_scope_name` - Filter by OpenTelemetry scope name (default: "apollo/router")