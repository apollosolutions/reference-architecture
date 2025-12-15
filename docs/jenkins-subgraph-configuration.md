# Configuring Subgraphs in Jenkins Pipeline

This guide explains how to configure which subgraphs are processed in the Jenkins pipeline.

## Default Behavior

By default, the pipeline processes only the **checkout** subgraph. This is configured to start small and add more subgraphs as needed.

## Configuring Subgraphs

### Option 1: Environment Variable (Recommended)

Set the `SUBGRAPHS` environment variable in Jenkins:

1. Go to **Manage Jenkins** → **Configure System**
2. Scroll to **Global properties** → **Environment variables**
3. Add:
   - **Name**: `SUBGRAPHS`
   - **Value**: `checkout` (or comma-separated list like `checkout,discovery,inventory`)

### Option 2: Job-Level Environment Variable

1. Go to your Jenkins job: `reference-architecture`
2. Click **Configure**
3. Scroll to **Build Environment**
4. Check **Use secret text(s) or file(s)**
5. Or add to **Pipeline** → **Environment** section

### Option 3: Build Parameter

You can modify the Jenkinsfile to accept a build parameter:

```groovy
parameters {
    string(name: 'SUBGRAPHS', defaultValue: 'checkout', description: 'Comma-separated list of subgraphs')
}
```

Then use `${params.SUBGRAPHS}` instead of `${env.SUBGRAPHS}`.

## Subgraph Names

Available subgraphs:
- `checkout`
- `discovery`
- `inventory`
- `orders`
- `products`
- `reviews`
- `shipping`
- `users`

## Examples

### Single Subgraph (Default)
```
SUBGRAPHS=checkout
```

### Multiple Subgraphs
```
SUBGRAPHS=checkout,discovery,inventory
```

### All Subgraphs
```
SUBGRAPHS=checkout,discovery,inventory,orders,products,reviews,shipping,users
```

## Processing Order

Subgraphs are processed **sequentially** (one at a time), not in parallel:

1. **Check Stage**: Each subgraph is checked individually
   - Checkout → Discovery → Inventory → etc.
2. **Publish Stage**: Each subgraph is published individually
   - Checkout → Discovery → Inventory → etc.
3. **Compose Stage**: Supergraph is composed from all published subgraphs

## Local Script Usage

When running `./scripts/jenkins/run-all.sh` locally:

```bash
# Process only checkout (default)
./scripts/jenkins/run-all.sh dev

# Process multiple subgraphs
SUBGRAPHS="checkout,discovery" ./scripts/jenkins/run-all.sh dev

# Process all subgraphs
SUBGRAPHS="checkout,discovery,inventory,orders,products,reviews,shipping,users" ./scripts/jenkins/run-all.sh dev
```

## Adding More Subgraphs

To add more subgraphs to your pipeline:

1. **Update Environment Variable**:
   ```bash
   # In Jenkins: Manage Jenkins → Configure System → Environment variables
   SUBGRAPHS=checkout,discovery,inventory
   ```

2. **Or Update Job Configuration**:
   - Go to job → Configure
   - Add `SUBGRAPHS` to environment variables

3. **Test with Manual Build**:
   - Click "Build Now"
   - Verify only specified subgraphs are processed

## Verification

After configuring, verify in build logs:

```
Processing 1 subgraph(s): checkout
```

Or for multiple:

```
Processing 3 subgraph(s): checkout, discovery, inventory
```

## Troubleshooting

### All Subgraphs Running Instead of Selected Ones

- Check environment variable is set correctly
- Verify variable name is exactly `SUBGRAPHS` (case-sensitive)
- Check if variable is overridden in job configuration

### Subgraph Not Found

- Verify subgraph name matches exactly (case-sensitive)
- Check subgraph directory exists: `subgraphs/{name}/schema.graphql`
- Ensure no extra spaces in comma-separated list

### Build Fails on Specific Subgraph

- Check build logs for specific subgraph errors
- Verify subgraph schema is valid
- Check Apollo GraphOS permissions for the subgraph


