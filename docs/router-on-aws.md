# Deploying Apollo Router on AWS

> A consolidated reference for SAs/SEs covering the three AWS deployment patterns we hit most often. Tracks [AS-208](https://apollographql.atlassian.net/browse/AS-208).

## Choosing a deployment target

| Target | When to use | Trade-offs |
| --- | --- | --- |
| **ECS Fargate** | Simplest path. No cluster to manage; ALB in front; logs into CloudWatch. | Cold-start tail latency on burst scale-out; no DaemonSet sidecars. |
| **EKS** | Customer already runs Kubernetes; needs sidecars (Fluent Bit, OTel collector); wants the [Apollo GraphOS Operator](https://www.apollographql.com/docs/apollo-operator/) for declarative supergraph management. | Cluster ops overhead; IRSA setup; more moving parts. |
| **EC2 (or App Runner)** | Fits inside an existing instance fleet; or App Runner for managed scale-to-zero. | Manual scaling story on EC2; App Runner has fewer knobs than ECS. |

For new customers without a strong existing preference, start with **ECS Fargate**. Promote to EKS when they outgrow it or need K8s-native operations.

## ECS Fargate — minimum viable deploy

```jsonc
// Task definition (excerpt)
{
  "family": "apollo-router",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "1024",
  "memory": "2048",
  "executionRoleArn": "arn:aws:iam::ACCOUNT:role/ecsTaskExecutionRole",
  "taskRoleArn": "arn:aws:iam::ACCOUNT:role/RouterTaskRole",
  "containerDefinitions": [
    {
      "name": "router",
      "image": "ghcr.io/apollographql/router:v2.10.0",
      "portMappings": [{ "containerPort": 4000, "protocol": "tcp" }],
      "essential": true,
      "environment": [
        { "name": "APOLLO_GRAPH_REF", "value": "my-graph@main" },
        { "name": "APOLLO_ROUTER_LOG", "value": "info" }
      ],
      "secrets": [
        {
          "name": "APOLLO_KEY",
          "valueFrom": "arn:aws:secretsmanager:us-east-1:ACCOUNT:secret:apollo/key"
        }
      ],
      "healthCheck": {
        "command": ["CMD-SHELL", "curl -f http://localhost:8088/health || exit 1"],
        "interval": 10,
        "timeout": 3,
        "retries": 3,
        "startPeriod": 30
      },
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/ecs/apollo-router",
          "awslogs-region": "us-east-1",
          "awslogs-stream-prefix": "router"
        }
      }
    }
  ]
}
```

Front it with an ALB on port 443 with an ACM cert, target group health-checks against `/health` on container port 8088 (the Router's [health-check endpoint](https://www.apollographql.com/docs/graphos/routing/self-hosted/health-checks)).

## EKS — operator-driven deploy

The reference architecture in this repo (`apollosolutions/reference-architecture`) is the canonical example of operator-driven Router on Kubernetes. Run the same setup on EKS by:

1. Provisioning an EKS cluster with [IRSA](https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts.html) — every Apollo pod that talks to AWS (Router itself only does if you use SigV4 to subgraphs; coprocessors often do for Secrets Manager / DynamoDB) gets a scoped role.
2. Installing the [Apollo GraphOS Operator](https://www.apollographql.com/docs/apollo-operator/installation/).
3. Applying the `Supergraph` CRD with `spec.routerConfig` inlined — see [`deploy/operator-resources/supergraph-prod.yaml`](../deploy/operator-resources/supergraph-prod.yaml).

Use non-OCI Helm patterns if the cluster can't reach `oci://ghcr.io/...` — see AS-239 for examples (pending merge into this repo).

## EC2 / App Runner

- **EC2**: pull the static binary or run the container under systemd. Attach an instance profile if Router needs SigV4 to subgraphs. Manual ASG scaling; less common for new deployments.
- **App Runner**: point at a container image, set env vars (`APOLLO_GRAPH_REF`, `APOLLO_KEY`), expose port 4000. Good for small teams; loses fine-grained control over logging sidecars.

## Auth on AWS

See companion tech note `router-aws-jwt-sigv4.md` (AS-184, pending merge) for the JWT + SigV4 combination — the most common authentication shape on AWS deployments.

## Observability

Router emits OTel traces, metrics, and logs. Wire them up via:

- **CloudWatch** — built-in via the awslogs log driver (ECS) or container stdout (EKS with the Fluent Bit DaemonSet). Captures logs only.
- **Managed Prometheus + Grafana** (AMP/AMG) — scrape the Router's Prometheus endpoint on `:9090/metrics`. The exporter is **disabled by default and binds `127.0.0.1`**; for AMP/sidecar scraping you must enable it and bind to the pod/task IP:

  ```yaml title="router.yaml"
  telemetry:
    exporters:
      metrics:
        prometheus:
          enabled: true
          listen: 0.0.0.0:9090
          path: /metrics
  ```

  Use the [router-grafana-template](https://github.com/apollosolutions/router-grafana-template) dashboard.
- **ADOT collector** — if you already use AWS Distro for OpenTelemetry, point Router OTLP exporter at the collector and fan out to X-Ray / CloudWatch / Managed Prometheus from there.

## Common pitfalls

- **Health checks** must hit `:8088/health`, not `:4000` — the Router serves graphql on 4000 and health on 8088 by default. ALB targeting 4000 with default settings will mark tasks unhealthy. The endpoint also binds `127.0.0.1` by default, so an external ALB or kubelet probe can't reach it — set `health_check.listen: 0.0.0.0:8088`:

  ```yaml title="router.yaml"
  health_check:
    enabled: true
    listen: 0.0.0.0:8088
    path: /health
  ```
- **Uplink reachability** — Router needs outbound HTTPS to `uplink.api.apollographql.com`. Verify NAT/egress rules in private subnets.
- **Memory** — set the task memory limit at least 1 GiB above `APOLLO_ROUTER_MAX_MEMORY` (or expect OOM on cold compilation of large schemas).
- **Secrets** — never embed `APOLLO_KEY` in the task definition env block. Use Secrets Manager via `secrets.valueFrom`.

## See also

- Router on AWS JWT + SigV4 — `router-aws-jwt-sigv4.md` (AS-184, pending merge)
- Non-OCI Helm chart examples — AS-239 (pending merge)
- [Apollo GraphOS Operator docs](https://www.apollographql.com/docs/apollo-operator/)
- [Router self-hosted runtime](https://www.apollographql.com/docs/graphos/routing/self-hosted/containerization/docker)
