# Jenkins CI/CD Overview

This document provides an overview of the Jenkins CI/CD setup for the Apollo Federation Reference Architecture.

## What You Get

A complete CI/CD pipeline that automatically:

1. ✅ **Detects changed subgraphs** by analyzing git diffs
2. ✅ **Validates** changed subgraph schemas using `rover subgraph check`
3. ✅ **Publishes** changed subgraph schemas to Apollo GraphOS using `rover subgraph publish`
4. ✅ **Composes** the supergraph using `rover supergraph compose` (separate pipeline)

## Pipeline Structure

The Jenkins setup consists of multiple pipeline files:

- **`Jenkinsfile.ci`**: Main CI pipeline for the `workshop-jenkins-ci` branch
  - Detects changed subgraphs automatically
  - Runs checks and publishes only changed subgraphs
  - Includes mock deployment stage
  
- **`Jenkinsfile.pr`**: Pull request pipeline
  - Validates changed subgraphs in PRs
  - Only runs checks (no publishing)
  - Updates GitHub status checks

- **`Jenkinsfile.check`**: Parameterized job for checking a single subgraph
  - Manual trigger with subgraph selection
  - Useful for testing individual subgraphs

- **`Jenkinsfile.publish`**: Parameterized job for publishing a single subgraph
  - Manual trigger with subgraph selection
  - Useful for manual publishing

- **`Jenkinsfile.compose`**: Supergraph composition pipeline
  - Composes supergraph from all published subgraphs
  - Generates `supergraph-{environment}.graphql` artifact

## How It Works

### Changed Subgraph Detection

The pipeline automatically detects which subgraphs have changed by:

1. Comparing current commit with previous commit (or target branch for PRs)
2. Analyzing changed files in the `subgraphs/` directory
3. Extracting unique subgraph names from file paths
4. Processing only the changed subgraphs

**Example**: If you modify `subgraphs/checkout/schema.graphql` and `subgraphs/inventory/src/index.ts`, the pipeline will process both `checkout` and `inventory` subgraphs.

### Pipeline Flow

```
┌─────────────┐
│   Checkout  │  Get code from repository
└──────┬──────┘
       │
┌──────▼──────────────────┐
│ Detect Changed Subgraphs│  Analyze git diff
└──────┬──────────────────┘
       │
┌──────▼──────────────────┐
│ Validate Environment    │  Check APOLLO_KEY, APOLLO_GRAPH_ID, Rover CLI
└──────┬──────────────────┘
       │
┌──────▼──────────────────┐
│ Subgraph Check (Parallel)│  Validate changed subgraph schemas
│  ✓ checkout (if changed) │
│  ✓ inventory (if changed)│
│  ...                     │
└──────┬──────────────────┘
       │
┌──────▼──────────────────┐
│ Subgraph Publish        │  Publish changed subgraphs to GraphOS
│  ✓ checkout (if changed) │
│  ✓ inventory (if changed)│
│  ...                     │
└──────┬──────────────────┘
       │
┌──────▼──────────────┐
│   ✅ Success        │
└─────────────────────┘
```

## Prerequisites

Before setting up Jenkins, ensure you have:

1. **Apollo GraphOS Account**
   - Personal API Key
   - Graph created (or use existing)
   - Graph ID configured

2. **Environment Variables**
   - `APOLLO_KEY`: Your Apollo GraphOS API key (configured as Jenkins credential)
   - `APOLLO_GRAPH_ID`: Your graph ID (set as Jenkins environment variable)
   - `ENVIRONMENT`: Environment name (defaults to `workshop-jenkins-ci` for CI pipeline)

3. **Rover CLI**
   - Automatically installed by Jenkinsfile if not found
   - Pre-installing is recommended for better performance

## Available Subgraphs

The pipeline can process these 8 subgraphs:

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

## Local Execution

You can run the pipeline locally without Jenkins:

```bash
# Set environment variables
export APOLLO_KEY="your-api-key"
export APOLLO_GRAPH_ID="your-graph-id"

# Run the complete pipeline
./scripts/jenkins/run-all.sh dev

# Or process specific subgraphs
SUBGRAPHS="checkout,discovery" ./scripts/jenkins/run-all.sh dev
```

## Documentation Structure

- **[jenkins-setup.md](./jenkins-setup.md)**: Complete setup guide for Jenkins
- **[jenkins-quick-reference.md](./jenkins-quick-reference.md)**: Quick reference for common tasks
- **[jenkins-local-triggers.md](./jenkins-local-triggers.md)**: Guide for triggering builds on local commits

## Next Steps

1. **Read the Setup Guide**: [jenkins-setup.md](./jenkins-setup.md)
2. **Test Locally**: Run `./scripts/jenkins/run-all.sh dev`
3. **Configure Jenkins**: Set up Jenkins job and credentials
4. **Set Up Triggers**: Configure SCM polling or webhooks for automatic builds
