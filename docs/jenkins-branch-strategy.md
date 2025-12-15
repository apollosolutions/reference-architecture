# Jenkins Branch Strategy and Publishing Rules

This guide explains how the Jenkins pipeline handles different branches and when publishing occurs.

## Publishing Rules

### When Publishing Happens

Publishing (subgraph publish and supergraph compose) **only occurs** when:

1. ✅ A **merge commit** is detected
2. ✅ The merge is **to the publish branch** (default: `workshop-jenkins-ci`)

### When Publishing is Skipped

Publishing is **skipped** when:

- ❌ Regular commits (non-merge commits)
- ❌ Commits on other branches
- ❌ Merge commits to branches other than the publish branch

### When Checks Always Run

**Subgraph checks always run** on:
- ✅ All commits (merge or regular)
- ✅ All branches
- ✅ Pull requests

This ensures schema validation happens on every change, but publishing only occurs on merges to the target branch.

## Configuration

### Publish Branch

The publish branch is configurable via the `PUBLISH_BRANCH` environment variable:

**Default**: `workshop-jenkins-ci`

**To change it**:

1. In Jenkins: **Manage Jenkins** → **Configure System** → **Environment variables**
2. Add:
   - **Name**: `PUBLISH_BRANCH`
   - **Value**: `your-branch-name`

Or set in job configuration.

## How It Works

### Detection Logic

The pipeline detects:
1. **Current branch**: Using `git rev-parse --abbrev-ref HEAD` (normalized to remove `origin/` prefix)
2. **Merge commit**: Checking multiple indicators:
   - Multiple parent commits (merge commits have 2+ parents)
   - Commit message contains "merge" or "Merge"
   - MERGE_HEAD file exists (for in-progress merges)
3. **Publish decision**: `IS_MERGE == true && CURRENT_BRANCH == PUBLISH_BRANCH`

### Pipeline Flow

```
┌─────────────────┐
│   Checkout      │  Get code
└────────┬────────┘
         │
┌────────▼──────────────┐
│ Validate Environment  │  Detect branch and merge status
└────────┬──────────────┘
         │
┌────────▼──────────────┐
│  Subgraph Check       │  ✅ Always runs
│  (All subgraphs)      │
└────────┬──────────────┘
         │
    ┌────┴────┐
    │         │
┌───▼───┐ ┌──▼──────────┐
│Publish│ │ Skip Publish│
│       │ │             │
│✅ Only│ │⏭️  When not  │
│on merge│ │  merge to   │
│to target│ │  target    │
│branch  │ │  branch    │
└───┬───┘ └──────────────┘
    │
┌───▼──────────────┐
│Supergraph Compose│  ✅ Only when publishing
└──────────────────┘
```

## Examples

### Example 1: Merge to Publish Branch

```bash
# On feature branch
git checkout feature/new-feature
git commit -m "Add new feature"
git push

# Merge to workshop-jenkins-ci
git checkout workshop-jenkins-ci
git merge feature/new-feature
git push
```

**Result**: 
- ✅ Checks run
- ✅ Publishing occurs
- ✅ Supergraph composed

### Example 2: Regular Commit to Publish Branch

```bash
# On publish branch
git checkout workshop-jenkins-ci
git commit -m "Update docs"
git push
```

**Result**:
- ✅ Checks run
- ❌ Publishing skipped (not a merge)
- ❌ Supergraph compose skipped

### Example 3: Merge to Different Branch

```bash
# Merge to main branch
git checkout main
git merge feature/new-feature
git push
```

**Result**:
- ✅ Checks run
- ❌ Publishing skipped (not merge to publish branch)
- ❌ Supergraph compose skipped

### Example 4: Commit on Feature Branch

```bash
# On feature branch
git checkout feature/new-feature
git commit -m "WIP"
git push
```

**Result**:
- ✅ Checks run
- ❌ Publishing skipped (not on publish branch)
- ❌ Supergraph compose skipped

## Build Logs

### When Publishing Occurs

```
Current Branch: workshop-jenkins-ci
Is Merge Commit: true
Should Publish: true
...
✅ Merge detected to workshop-jenkins-ci branch - Publishing subgraphs...
```

### When Publishing is Skipped

```
Current Branch: feature/new-feature
Is Merge Commit: false
Should Publish: false
...
⏭️  Skipping publish (not a merge to workshop-jenkins-ci branch)
   Current branch: feature/new-feature
   Is merge: false
   Publish branch: workshop-jenkins-ci
```

## Customizing the Publish Branch

### Option 1: Environment Variable

Set in Jenkins global configuration:

```bash
PUBLISH_BRANCH=main
```

### Option 2: Job Configuration

In Jenkins job configuration, add to environment variables:

```groovy
environment {
    PUBLISH_BRANCH = 'main'
}
```

### Option 3: Build Parameter

Modify Jenkinsfile to accept parameter:

```groovy
parameters {
    string(name: 'PUBLISH_BRANCH', defaultValue: 'workshop-jenkins-ci', description: 'Branch to publish on merge')
}
```

## Troubleshooting

### Publishing Not Happening

**Check**:
1. Is this a merge commit? Look for "Is Merge Commit: true" in logs
2. Is the current branch the publish branch? Check "Current Branch" in logs
3. Is `PUBLISH_BRANCH` set correctly?

### Publishing Happening When It Shouldn't

**Check**:
1. Verify `PUBLISH_BRANCH` is set to the correct branch
2. Check if merge detection is working correctly
3. Review build logs for branch detection

### Merge Detection Not Working

The pipeline uses multiple methods to detect merges:
- **Parent count**: Checks if commit has multiple parents
- **Commit message**: Looks for "merge" or "Merge" in commit message
- **MERGE_HEAD**: Checks for merge state file

This works for merge commits created by:
- `git merge` (creates merge commit with multiple parents)
- GitHub/GitLab merge commits (standard merge)
- Pull request merges (when not squashed)

**Note**: Squash merges and rebases create single-parent commits and won't be detected as merges. If you use squash merges, you may need to adjust the detection logic.

If merge detection fails, check:
- Git history shows merge commit (not squash/rebase): `git log --oneline --graph`
- Commit has multiple parents: `git cat-file -p HEAD | grep "^parent"`
- Commit message contains merge indicator

## Best Practices

1. **Use feature branches**: Develop on feature branches, merge to publish branch
2. **Keep publish branch clean**: Only merge tested code to publish branch
3. **Monitor checks**: Even if publishing is skipped, checks validate schemas
4. **Review before merge**: Ensure checks pass before merging to publish branch

