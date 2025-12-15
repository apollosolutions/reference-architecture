# Triggering Jenkins on Local Commits

This guide explains how to configure Jenkins to trigger builds when you make local commits, without requiring remote repository pushes.

## Options Overview

### Option 1: Git Post-Commit Hook (Recommended)
Automatically triggers Jenkins build after each local commit.

### Option 2: Jenkins CLI
Manually trigger builds from command line or scripts.

### Option 3: Manual Trigger
Click "Build Now" in Jenkins UI after committing.

### Option 4: Polling Local Repository
Configure Jenkins to poll your local repository for changes.

## Option 1: Git Post-Commit Hook (Automatic)

This automatically triggers a Jenkins build after you commit locally.

### Setup

1. **Install the git hook script:**

```bash
# Copy the hook script to your .git/hooks directory
cp scripts/jenkins/git-hooks/post-commit .git/hooks/post-commit
chmod +x .git/hooks/post-commit
```

2. **Configure Jenkins URL in the hook:**

Edit `.git/hooks/post-commit` and set:
```bash
JENKINS_URL="http://localhost:8080"
JENKINS_JOB="reference-architecture"
JENKINS_USER="your-username"  # Optional, for authentication
JENKINS_TOKEN="your-api-token"  # Optional, for authentication
```

3. **Get Jenkins API Token (if using authentication):**

   - Go to Jenkins → Your User → Configure
   - Click "Add new Token" under "API Token"
   - Copy the token and use it in the hook script

### How It Works

- After each `git commit`, the hook automatically triggers a Jenkins build
- The hook checks if Jenkins is accessible before triggering
- Build runs in the background (non-blocking)

### Disable Hook Temporarily

```bash
# Rename to disable
mv .git/hooks/post-commit .git/hooks/post-commit.disabled

# Re-enable
mv .git/hooks/post-commit.disabled .git/hooks/post-commit
```

## Option 2: Jenkins CLI (Manual/Scripted)

Use Jenkins CLI to trigger builds from command line or scripts.

### Setup

1. **Download Jenkins CLI JAR:**

```bash
# Create scripts/jenkins directory if it doesn't exist
mkdir -p scripts/jenkins

# Download Jenkins CLI
curl -o scripts/jenkins/jenkins-cli.jar http://localhost:8080/jnlpJars/jenkins-cli.jar
```

2. **Create trigger script:**

```bash
# scripts/jenkins/trigger-build.sh already created (see below)
chmod +x scripts/jenkins/trigger-build.sh
```

3. **Use the script:**

```bash
# Trigger build
./scripts/jenkins/trigger-build.sh

# Or with authentication
./scripts/jenkins/trigger-build.sh --user admin --token your-token
```

### Manual CLI Usage

```bash
# Without authentication
java -jar scripts/jenkins/jenkins-cli.jar \
  -s http://localhost:8080 \
  build reference-architecture

# With authentication
java -jar scripts/jenkins/jenkins-cli.jar \
  -s http://localhost:8080 \
  -auth username:api-token \
  build reference-architecture
```

## Option 3: Manual Trigger

Simply click "Build Now" in Jenkins UI after making local commits.

1. Make your local commits
2. Open Jenkins: `http://localhost:8080`
3. Navigate to your job: `reference-architecture`
4. Click **Build Now**

## Option 4: Polling Local Repository

Configure Jenkins to poll your local file system for changes.

### Setup

1. **In Jenkins job configuration:**

   - Go to **Build Triggers** section
   - Check **Poll SCM**
   - Enter schedule: `H/2 * * * *` (every 2 minutes)
   - In **Pipeline** or **Source Code Management**:
     - For Pipeline: Use `file://` path in Jenkinsfile
     - Or configure Git to point to local path

2. **Configure local Git repository:**

   In your Jenkinsfile or job config, use:
   ```groovy
   checkout([
       $class: 'GitSCM',
       userRemoteConfigs: [[
           url: "file://${env.WORKSPACE}/../reference-architecture"
       ]],
       branches: [[name: '*/main']]
   ])
   ```

   Or set repository URL to local path:
   ```
   file:///Users/andygarcia/code/nab-workshop/reference-architecture
   ```

## Recommended: Git Hook + Jenkins CLI Combination

Combine both approaches for maximum flexibility:

1. **Use git hook for automatic builds** (Option 1)
2. **Use CLI script for manual triggers** (Option 2)

This gives you:
- Automatic builds on commit (via hook)
- Manual control when needed (via CLI)

## Example: Git Post-Commit Hook Script

The hook script (`scripts/jenkins/git-hooks/post-commit`) will:

1. Check if Jenkins is running
2. Trigger the build via Jenkins API
3. Optionally wait for build to start
4. Show build URL

## Troubleshooting

### Hook Not Executing

- Verify hook is executable: `chmod +x .git/hooks/post-commit`
- Test manually: `.git/hooks/post-commit`
- Check git config: `git config core.hooksPath .git/hooks`

### Jenkins Not Accessible

- Verify Jenkins is running: `curl http://localhost:8080`
- Check firewall/network settings
- Verify Jenkins URL in hook script

### Authentication Errors

- Verify API token is correct
- Check user permissions in Jenkins
- Try without authentication first (if Jenkins allows anonymous builds)

### Build Not Triggering

- Check Jenkins job name matches
- Verify job exists and is enabled
- Check Jenkins logs: `~/.jenkins/logs/jenkins.log`

## Security Considerations

### For Local Development

- Git hooks are fine for local use
- No security concerns for local Jenkins

### For Shared Repositories

- **Don't commit hooks to repository** (they're in `.git/hooks/`)
- If sharing hooks, use a separate script that users install
- Consider using Jenkins CLI with authentication

## Next Steps

1. Choose your preferred option (recommended: Option 1 - Git Hook)
2. Install the hook or CLI script
3. Test with a local commit
4. Verify build triggers in Jenkins


