# Jenkins CI/CD Quick Reference

Quick reference guide for using Jenkins with this reference architecture.

## Quick Start

### 1. Manual Execution (Without Jenkins)

Run the complete pipeline locally:

```bash
cd /path/to/reference-architecture

# Set environment variables
export APOLLO_KEY="your-api-key"
export APOLLO_GRAPH_ID="your-graph-id"

# Run the complete pipeline
./scripts/jenkins/run-all.sh dev

# Or process specific subgraphs
SUBGRAPHS="checkout,discovery" ./scripts/jenkins/run-all.sh dev
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

- [ ] Install Jenkins (see [jenkins-setup.md](./jenkins-setup.md))
- [ ] Install required plugins (Pipeline, Git, GitHub)
- [ ] Install Rover CLI on Jenkins agent (optional, auto-installs if missing)
- [ ] Configure `APOLLO_KEY` credential in Jenkins (ID: `apollo-key`)
- [ ] Set `APOLLO_GRAPH_ID` environment variable
- [ ] Create Jenkins jobs from Jenkinsfiles
- [ ] Test with manual build

## Environment Variables

**Required:**
- `APOLLO_KEY`: Apollo GraphOS API key (configured as Jenkins credential)
- `APOLLO_GRAPH_ID`: Your graph ID (e.g., `my-graph`)

**Optional:**
- `ENVIRONMENT`: Environment name (default: `workshop-jenkins-ci` for CI pipeline)

**Graph reference format**: `${APOLLO_GRAPH_ID}@${ENVIRONMENT}`

## Available Subgraphs

The pipeline can process these 8 subgraphs:
1. checkout
2. discovery
3. inventory
4. orders
5. products
6. reviews
7. shipping
8. users

## Pipeline Files

- **Jenkinsfile.ci**: Main CI pipeline (detects changed subgraphs, checks and publishes)
- **Jenkinsfile.pr**: PR pipeline (checks changed subgraphs only)
- **Jenkinsfile.check**: Parameterized job for checking single subgraph
- **Jenkinsfile.publish**: Parameterized job for publishing single subgraph
- **Jenkinsfile.compose**: Supergraph composition pipeline

## Pipeline Stages

### CI Pipeline (Jenkinsfile.ci)

1. **Checkout**: Get code from repository
2. **Detect Changed Subgraphs**: Analyze git diff
3. **Validate Environment**: Verify configuration
4. **Subgraph Check**: Validate changed subgraph schemas (sequential)
5. **Deploy Subgraphs**: Mock deployment stage
6. **Subgraph Publish**: Publish changed subgraphs (sequential)

### PR Pipeline (Jenkinsfile.pr)

1. **Checkout PR**: Get PR code
2. **Detect Changed Subgraphs**: Compare with target branch
3. **Validate Environment**: Verify configuration
4. **Subgraph Check**: Validate changed subgraph schemas (parallel)

## Manual Trigger

### Via Jenkins UI

1. Go to job: `reference-architecture-ci`
2. Click **Build Now**

### Via API

```bash
curl -X POST http://localhost:8080/job/reference-architecture-ci/build \
  --user username:api-token
```

### Via Webhook (GitHub)

Configure webhook in GitHub:
- URL: `http://your-jenkins-url:8080/github-webhook/`
- Events: Push, Pull Request

## Changed Subgraph Detection

The pipeline automatically detects changed subgraphs by:
- Comparing commits (CI) or branches (PR)
- Analyzing changed files in `subgraphs/` directory
- Extracting unique subgraph names from file paths

**Example**: Modifying `subgraphs/checkout/schema.graphql` will process the `checkout` subgraph.

## Output

After successful build:
- **CI Pipeline**: Changed subgraphs checked and published
- **Compose Pipeline**: `supergraph-{environment}.graphql` artifact generated

## Common Tasks

### Check Single Subgraph Manually

Use parameterized job `Jenkinsfile.check`:
1. Select subgraph from dropdown
2. Select environment
3. Click Build

### Publish Single Subgraph Manually

Use parameterized job `Jenkinsfile.publish`:
1. Select subgraph from dropdown
2. Select environment
3. Click Build

### Compose Supergraph

Use `Jenkinsfile.compose` job:
1. Set `ENVIRONMENT` variable
2. Click Build
3. Download `supergraph-{environment}.graphql` artifact

## Next Steps

- Configure webhooks for automatic builds
- Set up notifications (email, Slack)
- Review build logs to verify everything works
- See [jenkins-setup.md](./jenkins-setup.md) for detailed setup
