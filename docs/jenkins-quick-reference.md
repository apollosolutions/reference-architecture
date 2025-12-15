# Jenkins CI/CD Quick Reference

Quick reference guide for using Jenkins with this reference architecture.

## Quick Start

### 1. Manual Execution (Without Jenkins)

Run the complete pipeline locally:

```bash
cd /path/to/reference-architecture
./scripts/jenkins/run-all.sh dev
```

### 2. Individual Commands

#### Check a single subgraph:
```bash
./scripts/jenkins/rover-check.sh checkout my-graph@dev
```

#### Publish a single subgraph:
```bash
./scripts/jenkins/rover-publish.sh checkout my-graph@dev
```

#### Compose supergraph:
```bash
./scripts/jenkins/rover-compose.sh my-graph@dev supergraph-dev.graphql
```

## Jenkins Setup Checklist

- [ ] Install Jenkins (see `jenkins-manual-setup.md`)
- [ ] Install required plugins (Pipeline, Git, GitHub)
- [ ] Install Rover CLI on Jenkins agent
- [ ] Configure `APOLLO_KEY` credential in Jenkins
- [ ] Set `APOLLO_GRAPH_ID` environment variable
- [ ] Create Jenkins job from Jenkinsfile
- [ ] Test with manual build

## Environment Variables

Required:
- `APOLLO_KEY`: Apollo GraphOS API key
- `APOLLO_GRAPH_ID`: Your graph ID (e.g., `my-graph`)

Optional:
- `ENVIRONMENT`: Environment name (default: `dev`)

Graph reference format: `${APOLLO_GRAPH_ID}@${ENVIRONMENT}`

## Subgraphs

The pipeline processes these 8 subgraphs:
1. checkout
2. discovery
3. inventory
4. orders
5. products
6. reviews
7. shipping
8. users

## Pipeline Stages

1. **Checkout**: Get code from repository
2. **Validate Environment**: Verify configuration
3. **Subgraph Check**: Validate all subgraph schemas (parallel)
4. **Subgraph Publish**: Publish all subgraphs (parallel)
5. **Supergraph Compose**: Compose final supergraph

## Troubleshooting

### Rover not found
```bash
curl -sSL https://rover.apollo.dev/nix/latest | sh
export PATH="$HOME/.rover/bin:$PATH"
```

### Authentication error
- Verify `APOLLO_KEY` is correct
- Check credential ID matches `apollo-key` in Jenkinsfile

### Schema check fails
- Review schema.graphql files
- Check Apollo GraphOS Studio for validation details

### Composition fails
- Ensure all subgraphs published successfully
- Check for schema conflicts

## Manual Trigger

### Via Jenkins UI
1. Go to job: `reference-architecture`
2. Click **Build Now**

### Via API
```bash
curl -X POST http://localhost:8080/job/reference-architecture/build \
  --user username:api-token
```

### Via Webhook (GitHub)
Configure webhook in GitHub:
- URL: `http://your-jenkins-url:8080/github-webhook/`
- Events: Push, Pull Request

## Files Created

After successful build:
- `supergraph-{environment}.graphql`: Composed supergraph schema

## Next Steps

- Configure webhooks for automatic builds
- Set up notifications (email, Slack)
- Add deployment stages
- Configure multiple environments

