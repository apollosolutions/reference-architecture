# Jenkins CI/CD Overview

This document provides an overview of the Jenkins CI/CD setup for the Apollo Federation Reference Architecture.

## What You Get

A complete CI/CD pipeline that automatically:

1. ✅ **Validates** all subgraph schemas using `rover subgraph check`
2. ✅ **Publishes** all subgraph schemas to Apollo GraphOS using `rover subgraph publish`
3. ✅ **Composes** the supergraph using `rover supergraph compose`

## Documentation Structure

- **[jenkins-setup.md](./jenkins-setup.md)**: Comprehensive guide explaining what needs to be done and when
- **[jenkins-manual-setup.md](./jenkins-manual-setup.md)**: Step-by-step instructions for setting up Jenkins
- **[jenkins-local-triggers.md](./jenkins-local-triggers.md)**: Guide for triggering builds on local commits
- **[jenkins-subgraph-configuration.md](./jenkins-subgraph-configuration.md)**: Configure which subgraphs to process
- **[jenkins-quick-reference.md](./jenkins-quick-reference.md)**: Quick reference for common tasks

## Files Created

### Configuration Files

- **`Jenkinsfile`**: Declarative pipeline definition (repository root)
- **`scripts/jenkins/supergraph-config.yaml`**: Optional supergraph composition configuration

### Helper Scripts

- **`scripts/jenkins/rover-check.sh`**: Check a single subgraph
- **`scripts/jenkins/rover-publish.sh`**: Publish a single subgraph
- **`scripts/jenkins/rover-compose.sh`**: Compose the supergraph
- **`scripts/jenkins/run-all.sh`**: Run the complete pipeline locally
- **`scripts/jenkins/trigger-build.sh`**: Manually trigger Jenkins build from CLI
- **`scripts/jenkins/git-hooks/post-commit`**: Git hook to auto-trigger builds on local commits

## Quick Start

### Option 1: Run Locally (No Jenkins Required)

```bash
# Set environment variables
export APOLLO_KEY="your-api-key"
export APOLLO_GRAPH_ID="your-graph-id"
export ENVIRONMENT="dev"

# Run the complete pipeline
./scripts/jenkins/run-all.sh dev
```

### Option 2: Use Jenkins

1. Follow [jenkins-manual-setup.md](./jenkins-manual-setup.md) to install and configure Jenkins
2. Create a Jenkins job using the `Jenkinsfile`
3. Configure credentials and environment variables
4. Trigger builds manually or via webhooks

## When Jenkins Runs

### Automatic Triggers

- **Local Commits**: Via git post-commit hook (see [Local Triggers Guide](./jenkins-local-triggers.md))
- **Remote Git Commits**: When code is pushed to any branch (if webhook/polling configured)
- **Pull Requests**: When a PR is created or updated (if GitHub integration configured)
- **Webhooks**: When configured with GitHub/GitLab
- **SCM Polling**: Periodic checks for repository changes

### Manual Triggers

- **Jenkins UI**: Click "Build Now" in the job
- **Command Line**: `./scripts/jenkins/trigger-build.sh`
- **API**: POST request to Jenkins build endpoint

## Pipeline Flow

```
┌─────────────┐
│   Checkout  │  Get code from repository
└──────┬──────┘
       │
┌──────▼──────────┐
│ Validate Env    │  Check APOLLO_KEY, APOLLO_GRAPH_ID, Rover CLI
└──────┬──────────┘
       │
┌──────▼─────────────────────┐
│ Subgraph Check (Parallel)   │  Validate all 8 subgraph schemas
│  ✓ checkout                 │
│  ✓ discovery                │
│  ✓ inventory                │
│  ✓ orders                   │
│  ✓ products                 │
│  ✓ reviews                  │
│  ✓ shipping                 │
│  ✓ users                    │
└──────┬───────────────────────┘
       │
┌──────▼─────────────────────┐
│ Subgraph Publish (Parallel) │  Publish all 8 subgraphs to GraphOS
│  ✓ checkout                 │
│  ✓ discovery                │
│  ✓ inventory                │
│  ✓ orders                   │
│  ✓ products                 │
│  ✓ reviews                  │
│  ✓ shipping                 │
│  ✓ users                    │
└──────┬───────────────────────┘
       │
┌──────▼──────────────┐
│ Supergraph Compose  │  Compose all subgraphs into supergraph
└──────┬──────────────┘
       │
┌──────▼──────────────┐
│   ✅ Success        │  Archive supergraph.graphql
└─────────────────────┘
```

## Prerequisites

Before setting up Jenkins, ensure you have:

1. **Apollo GraphOS Account**
   - Personal API Key
   - Graph created (or use existing)
   - Graph ID and variant configured

2. **Environment Variables**
   - `APOLLO_KEY`: Your Apollo GraphOS API key
   - `APOLLO_GRAPH_ID`: Your graph ID
   - `ENVIRONMENT`: Environment name (e.g., `dev`, `prod`)

3. **Rover CLI**
   - Installed on Jenkins agent/node
   - Or will be installed automatically by Jenkinsfile

## Subgraphs Processed

The pipeline processes 8 subgraphs in parallel:

| Subgraph | Schema Location | Routing URL (default) |
|----------|----------------|---------------------|
| checkout | `subgraphs/checkout/schema.graphql` | `http://graphql.checkout.svc.cluster.local:4001` |
| discovery | `subgraphs/discovery/schema.graphql` | `http://graphql.discovery.svc.cluster.local:4002` |
| inventory | `subgraphs/inventory/schema.graphql` | `http://graphql.inventory.svc.cluster.local:4003` |
| orders | `subgraphs/orders/schema.graphql` | `http://graphql.orders.svc.cluster.local:4004` |
| products | `subgraphs/products/schema.graphql` | `http://graphql.products.svc.cluster.local:4005` |
| reviews | `subgraphs/reviews/schema.graphql` | `http://graphql.reviews.svc.cluster.local:4006` |
| shipping | `subgraphs/shipping/schema.graphql` | `http://graphql.shipping.svc.cluster.local:4007` |
| users | `subgraphs/users/schema.graphql` | `http://graphql.users.svc.cluster.local:4008` |

**Note**: By default, only the `checkout` subgraph is processed. Configure via `SUBGRAPHS` environment variable. See [Subgraph Configuration Guide](./jenkins-subgraph-configuration.md).

## Output

After a successful build:

- **Supergraph Schema**: `supergraph-{environment}.graphql`
  - Composed from all published subgraphs
  - Available as a build artifact in Jenkins
  - Can be used for router deployment

## Integration with Existing Setup

This Jenkins setup integrates with your existing Minikube/Kubernetes setup:

- **Subgraph Schemas**: Uses existing `schema.graphql` files in each subgraph
- **GraphOS Integration**: Publishes to the same GraphOS graph/variant used by the operator
- **Environment Support**: Respects the `ENVIRONMENT` variable (dev/prod)

## Next Steps

1. **Read the Setup Guide**: [jenkins-setup.md](./jenkins-setup.md)
2. **Follow Manual Setup**: [jenkins-manual-setup.md](./jenkins-manual-setup.md)
3. **Set Up Local Triggers**: [jenkins-local-triggers.md](./jenkins-local-triggers.md) (for local commit triggers)
4. **Test Locally**: Run `./scripts/jenkins/run-all.sh dev`
5. **Configure Jenkins**: Set up Jenkins job and credentials
6. **Set Up Triggers**: Configure local git hooks or webhooks for automatic builds

## Support

For issues or questions:

- Check [jenkins-quick-reference.md](./jenkins-quick-reference.md) for common tasks
- Review build logs in Jenkins for specific errors
- Check Apollo GraphOS Studio for schema validation details
- Review the main [setup.md](./setup.md) for environment configuration

