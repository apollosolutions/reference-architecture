# Subgraph Detection and Configuration

This guide explains how the Jenkins pipeline detects and processes subgraphs.

## Automatic Changed Subgraph Detection

The pipeline **automatically detects** which subgraphs have changed by analyzing git diffs. You don't need to manually configure which subgraphs to process.

### How It Works

1. **For CI Pipeline (Jenkinsfile.ci)**:
   - Compares current commit with previous commit
   - Analyzes changed files in `subgraphs/` directory
   - Extracts unique subgraph names from file paths

2. **For PR Pipeline (Jenkinsfile.pr)**:
   - Compares PR branch with target branch (`workshop-jenkins-ci`)
   - Analyzes changed files in `subgraphs/` directory
   - Extracts unique subgraph names from file paths

3. **Processing**:
   - Only changed subgraphs are checked and published
   - If no subgraphs changed, stages are skipped

### Example Detection

If you modify these files:
- `subgraphs/checkout/schema.graphql`
- `subgraphs/inventory/src/index.ts`
- `subgraphs/orders/package.json`

The pipeline will detect and process:
- `checkout`
- `inventory`
- `orders`

## Available Subgraphs

The pipeline can process these 8 subgraphs:

- `checkout`
- `discovery`
- `inventory`
- `orders`
- `products`
- `reviews`
- `shipping`
- `users`

## Manual Subgraph Selection (Local Scripts)

When running scripts locally (`scripts/jenkins/run-all.sh`), you can specify which subgraphs to process:

### Single Subgraph (Default)

```bash
./scripts/jenkins/run-all.sh dev
# Processes: checkout (default)
```

### Multiple Subgraphs

```bash
SUBGRAPHS="checkout,discovery,inventory" ./scripts/jenkins/run-all.sh dev
```

### All Subgraphs

```bash
SUBGRAPHS="checkout,discovery,inventory,orders,products,reviews,shipping,users" ./scripts/jenkins/run-all.sh dev
```

## Parameterized Jobs

For manual testing, you can use parameterized jobs:

### Jenkinsfile.check

- **Parameter**: `SUBGRAPH` (dropdown selection)
- **Parameter**: `ENVIRONMENT` (dropdown: `workshop-jenkins-ci`, `dev`)
- **Behavior**: Checks a single subgraph

### Jenkinsfile.publish

- **Parameter**: `SUBGRAPH` (dropdown selection)
- **Parameter**: `ENVIRONMENT` (dropdown: `workshop-jenkins-ci`, `dev`)
- **Behavior**: Publishes a single subgraph

## Processing Order

### CI Pipeline

Subgraphs are processed **sequentially** (one at a time):

1. **Check Stage**: Each changed subgraph is checked individually
   - Checkout → Inventory → Orders → etc.
2. **Publish Stage**: Each changed subgraph is published individually
   - Checkout → Inventory → Orders → etc.

### PR Pipeline

Subgraphs are processed **in parallel**:

1. **Check Stage**: All changed subgraphs checked in parallel
   - Checkout ✓ | Inventory ✓ | Orders ✓ (simultaneously)

## Verification

After a build, check the logs to see which subgraphs were detected:

```
Detecting changed subgraphs...
Changed files in subgraphs:
subgraphs/checkout/schema.graphql
subgraphs/inventory/src/index.ts
Changed subgraphs detected: checkout, inventory
```

Or when no changes:

```
Detecting changed subgraphs...
No changes detected in subgraphs directory
⏭️  No subgraph changes detected. Skipping check and publish stages.
```

## Troubleshooting

### All Subgraphs Running Instead of Changed Ones

- This shouldn't happen with automatic detection
- Check build logs for "Changed subgraphs detected" message
- Verify git diff is working correctly

### Subgraph Not Detected

- Verify the file path matches pattern: `subgraphs/{name}/...`
- Check that changes are in the `subgraphs/` directory
- Ensure changes are committed and pushed

### Build Fails on Specific Subgraph

- Check build logs for specific subgraph errors
- Verify subgraph schema is valid
- Check Apollo GraphOS permissions for the subgraph
