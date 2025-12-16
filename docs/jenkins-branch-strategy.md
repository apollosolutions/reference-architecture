# Jenkins Branch Strategy

This guide explains how the Jenkins pipelines handle different branches and when processing occurs.

## Pipeline Behavior

### Main CI Pipeline (Jenkinsfile.ci)

- **Target Branch**: `workshop-jenkins-ci`
- **Behavior**: 
  - Processes all commits pushed to this branch
  - Detects changed subgraphs automatically
  - Runs checks and publishes changed subgraphs
  - Includes mock deployment stage

### Pull Request Pipeline (Jenkinsfile.pr)

- **Target Branch**: `workshop-jenkins-ci`
- **Behavior**:
  - Processes pull requests targeting `workshop-jenkins-ci`
  - Detects changed subgraphs in the PR
  - Runs checks only (no publishing)
  - Updates GitHub status checks

### Changed Subgraph Detection

The pipeline automatically detects which subgraphs have changed by:

1. **For CI Pipeline**: Comparing current commit with previous commit
2. **For PR Pipeline**: Comparing PR branch with target branch (`workshop-jenkins-ci`)
3. Analyzing changed files in the `subgraphs/` directory
4. Extracting unique subgraph names from file paths
5. Processing only the changed subgraphs

**Example**: If you modify `subgraphs/checkout/schema.graphql` and `subgraphs/inventory/src/index.ts`, the pipeline will process both `checkout` and `inventory` subgraphs.

## When Processing Occurs

### CI Pipeline (Jenkinsfile.ci)

- ✅ **All commits** to `workshop-jenkins-ci` branch
- ✅ **All changed subgraphs** are checked and published
- ✅ Triggered by SCM polling (every 2 minutes) or webhooks

### PR Pipeline (Jenkinsfile.pr)

- ✅ **Pull requests** targeting `workshop-jenkins-ci`
- ✅ **Only changed subgraphs** are checked (no publishing)
- ✅ Triggered automatically when PR is created/updated

### Parameterized Jobs

- **Jenkinsfile.check**: Manual trigger, checks single subgraph
- **Jenkinsfile.publish**: Manual trigger, publishes single subgraph
- **Jenkinsfile.compose**: Manual trigger, composes supergraph

## Examples

### Example 1: Commit to CI Branch

```bash
# On workshop-jenkins-ci branch
git checkout workshop-jenkins-ci
git commit -m "Update checkout schema"
git push
```

**Result**: 
- ✅ Changed subgraphs detected: `checkout`
- ✅ Check runs
- ✅ Publish runs

### Example 2: Pull Request

```bash
# Create feature branch
git checkout -b feature/new-feature
git commit -m "Update inventory schema"
git push

# Create PR targeting workshop-jenkins-ci
```

**Result**:
- ✅ Changed subgraphs detected: `inventory`
- ✅ Check runs
- ❌ Publish skipped (PR pipeline doesn't publish)

### Example 3: Multiple Subgraphs Changed

```bash
# Modify multiple subgraphs
git checkout workshop-jenkins-ci
# Edit subgraphs/checkout/schema.graphql
# Edit subgraphs/inventory/src/index.ts
git commit -m "Update multiple subgraphs"
git push
```

**Result**:
- ✅ Changed subgraphs detected: `checkout, inventory`
- ✅ Both checked in parallel
- ✅ Both published

## Build Logs

### When Subgraphs Are Detected

```
Detecting changed subgraphs...
Previous commit: abc123
Current commit: def456
Changed files in subgraphs:
subgraphs/checkout/schema.graphql
subgraphs/inventory/src/index.ts
Changed subgraphs detected: checkout, inventory
```

### When No Changes Detected

```
Detecting changed subgraphs...
No changes detected in subgraphs directory
⏭️  No subgraph changes detected. Skipping check and publish stages.
```

## Best Practices

1. **Use feature branches**: Develop on feature branches, merge to `workshop-jenkins-ci`
2. **Keep CI branch clean**: Only merge tested code to `workshop-jenkins-ci`
3. **Monitor checks**: PR checks validate schemas before merge
4. **Review before merge**: Ensure PR checks pass before merging to CI branch

## Configuration

### Changing the Target Branch

To change the target branch from `workshop-jenkins-ci`:

1. **Update Jenkinsfile.ci**:
   ```groovy
   branches: [[name: 'origin/your-branch-name']]
   ```

2. **Update Jenkinsfile.pr**:
   ```groovy
   def targetBranch = env.CHANGE_TARGET ?: 'your-branch-name'
   ```

3. **Update environment variable**:
   ```groovy
   ENVIRONMENT = "your-branch-name"
   APOLLO_GRAPH_REF = "${env.APOLLO_GRAPH_ID}@your-branch-name"
   ```
