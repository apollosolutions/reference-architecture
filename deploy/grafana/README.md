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

### Dashboard Requirements

This dashboard requires:
- Grafana
- A Prometheus datasource
- Prometheus gathering metrics from the Apollo Router running v2.0 or higher

This dashboard also leverages the following telemetry configuration for the router:

```yaml
telemetry:
  instrumentation:
    instruments:
      default_requirement_level: required
      router:
        http.server.request.duration:
          attributes:
            graphql.operation.name:
              operation_name: string
            graphql.errors:
              on_graphql_error: true
        http.server.request.body.size: true
        http.server.response.body.size: true
        http.server.active_requests: true
      subgraph:
        http.client.request.duration:
          attributes:
            subgraph.name: true
        http.client.request.body.size:
          attributes:
            subgraph.name: true
        http.client.response.body.size: true
```

### Usage

Once imported, select your datasource in the top variable section and the dashboard should populate so long as you use the standard metric values.

Dashboard variables:
- `otel_scope_name` - Filter by OpenTelemetry scope name (default: "apollo/router")

### Known Limitations

- **HTTP status codes are not available** as attributes on subgraph client metrics (`http.client.request.duration`). The dashboard shows subgraph metrics grouped by subgraph name only, without status code breakdowns. Router-level metrics do include status code information.

- The template does not include any panels for resource views; this data is often bespoke to the environments in which the router is run, therefore it is easier to add your own panels from the correct datasources.

- There are sections for resources, however, to be able to input the necessary panels.