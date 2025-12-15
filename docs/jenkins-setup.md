# Jenkins CI/CD Setup Guide

This guide explains how to set up Jenkins for automated CI/CD with Apollo Rover commands for this reference architecture.

## Overview

Jenkins will automatically run the following Rover commands when code changes are detected:

1. **Rover Subgraph Check** - Validates each subgraph schema against Apollo GraphOS
2. **Rover Subgraph Publish** - Publishes each subgraph schema to Apollo GraphOS
3. **Rover Supergraph Compose** - Composes all subgraphs into a supergraph

## When Jenkins Runs

Jenkins will trigger builds on:

- **Local Commits**: Automatically via git hooks, or manually via CLI (see [Local Triggers Guide](./jenkins-local-triggers.md))
- **Remote Git Commits**: When code is pushed to any branch (if webhook/polling configured)
- **Pull Requests**: When a PR is created or updated (if GitHub integration is configured)
- **Manual**: Click "Build Now" in Jenkins UI

## Publishing Rules

**Important**: Publishing (subgraph publish and supergraph compose) **only occurs** when:
- ✅ A merge commit is detected
- ✅ The merge is to the publish branch (default: `workshop-jenkins-ci`)

**Subgraph checks always run** on all commits and branches.

See [Branch Strategy Guide](./jenkins-branch-strategy.md) for detailed information.

## Prerequisites

Before setting up Jenkins, ensure you have:

1. **Apollo GraphOS Account** with:
   - Personal API Key (for initial setup)
   - Graph ID and variant configured
   - All subgraphs registered in GraphOS

2. **Environment Variables** configured:
   - `APOLLO_KEY`: Your Apollo GraphOS API key
   - `APOLLO_GRAPH_REF`: Graph reference in format `graph-id@variant` (e.g., `my-graph@dev`)
   - `ENVIRONMENT`: Environment name (e.g., `dev`, `prod`)

3. **Rover CLI** installed on the Jenkins agent/node
   
   > **Note**: The Jenkinsfile includes automatic Rover installation, but pre-installing it is recommended for better performance. See [Installing Rover CLI on Jenkins](#installing-rover-cli-on-jenkins) below for detailed instructions.

4. **Git** configured (if using GitHub integration)

## What Gets Checked

### Subgraph Check (`rover subgraph check`)

For each subgraph, Jenkins will:
- Validate the schema syntax
- Check for breaking changes against the published schema in GraphOS
- Verify federation directives are correct
- Ensure schema compatibility with other subgraphs

**Subgraphs checked:**
- By default: `checkout` only
- Configurable via `SUBGRAPHS` environment variable (comma-separated)
- Available: `checkout`, `discovery`, `inventory`, `orders`, `products`, `reviews`, `shipping`, `users`

See [Subgraph Configuration Guide](./jenkins-subgraph-configuration.md) for details.

### Subgraph Publish (`rover subgraph publish`)

After successful checks, Jenkins will:
- Publish each subgraph schema to Apollo GraphOS
- Update the schema in the specified variant
- Make the schema available for composition

### Supergraph Compose (`rover supergraph compose`)

After all subgraphs are published, Jenkins will:
- Compose all subgraphs into a single supergraph schema
- Validate the composed schema
- Generate the supergraph schema file

## Workflow

### On Every Commit/PR

1. **Checkout code** from repository
2. **Install dependencies** (if needed)
3. **For each subgraph:**
   - Run `rover subgraph check` with the subgraph schema
   - If check passes, run `rover subgraph publish`
4. **After all subgraphs published:**
   - Run `rover supergraph compose` to compose the supergraph
5. **Report results** (success/failure)

### Failure Handling

- If any subgraph check fails, the build fails
- If any subgraph publish fails, the build fails
- If supergraph compose fails, the build fails
- Build logs will show which subgraph/step failed

## Manual Triggering

You can manually trigger Jenkins builds:

1. **Via Jenkins UI:**
   - Navigate to your Jenkins job
   - Click "Build Now"

2. **Via Webhook (if configured):**
   - Make a commit to your repository
   - Push to GitHub (if webhook is set up)

3. **Via API:**
   ```bash
   curl -X POST http://localhost:8080/job/reference-architecture/build \
     --user username:api-token
   ```

## Configuration Files

The Jenkins setup uses:

- **Jenkinsfile**: Declarative pipeline definition (in repository root)
- **scripts/jenkins/rover-check.sh**: Helper script for subgraph checks
- **scripts/jenkins/rover-publish.sh**: Helper script for subgraph publishing
- **scripts/jenkins/rover-compose.sh**: Helper script for supergraph composition

## Environment-Specific Behavior

The Jenkins pipeline respects the `ENVIRONMENT` variable:

- **dev**: Uses `@dev` variant in GraphOS
- **prod**: Uses `@prod` variant in GraphOS
- **Custom**: Uses `@custom` variant (if configured)

Each environment publishes to its own variant, allowing parallel development and testing.

## Local Commit Triggers

Want Jenkins to trigger on **local commits** instead of remote pushes? See the [Local Triggers Guide](./jenkins-local-triggers.md) for:

- Git post-commit hooks (automatic triggers)
- Jenkins CLI scripts (manual triggers)
- Local repository polling

## Next Steps

1. Follow the [Manual Jenkins Setup Instructions](./jenkins-manual-setup.md) to install and configure Jenkins
2. Configure the Jenkinsfile with your Apollo GraphOS credentials
3. Set up local triggers (see [Local Triggers Guide](./jenkins-local-triggers.md)) or webhooks for automatic triggering
4. Test the pipeline with a manual build

## Installing Rover CLI on Jenkins

The Jenkinsfile automatically installs Rover if it's not found, but **pre-installing Rover is recommended** for better build performance. Here are detailed instructions for different Jenkins setups:

### Option 1: Local Jenkins (Same Machine)

If Jenkins is running on your local machine:

```bash
# Install Rover CLI
curl -sSL https://rover.apollo.dev/nix/latest | sh

# Add to PATH permanently
echo 'export PATH="$HOME/.rover/bin:$PATH"' >> ~/.zshrc  # For zsh
# OR
echo 'export PATH="$HOME/.rover/bin:$PATH"' >> ~/.bashrc  # For bash

# Reload shell configuration
source ~/.zshrc  # or source ~/.bashrc

# Verify installation
rover --version
```

**For Jenkins user specifically** (if Jenkins runs as a different user):

```bash
# Switch to Jenkins user (if applicable)
sudo su - jenkins  # or the user running Jenkins

# Install Rover
curl -sSL https://rover.apollo.dev/nix/latest | sh

# Add to PATH
echo 'export PATH="$HOME/.rover/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc

# Verify
rover --version
```

### Option 2: Remote Jenkins Agent/Node

If Jenkins uses remote agents:

1. **SSH into the agent node:**
   ```bash
   ssh user@jenkins-agent-host
   ```

2. **Install Rover:**
   ```bash
   curl -sSL https://rover.apollo.dev/nix/latest | sh
   export PATH="$HOME/.rover/bin:$PATH"
   rover --version
   ```

3. **Make it permanent:**
   ```bash
   echo 'export PATH="$HOME/.rover/bin:$PATH"' >> ~/.bashrc
   ```

4. **Configure Jenkins Node:**
   - Go to **Manage Jenkins** → **Manage Nodes and Clouds**
   - Select your agent node
   - Under **Node Properties**, add environment variable:
     - **Name**: `PATH`
     - **Value**: `$HOME/.rover/bin:$PATH` (or full path: `/home/user/.rover/bin:$PATH`)

### Option 3: Docker Agent

If using Docker agents, create a custom Docker image:

**Dockerfile:**
```dockerfile
FROM jenkins/inbound-agent:latest

USER root

# Install Rover CLI
RUN curl -sSL https://rover.apollo.dev/nix/latest | sh

# Add Rover to PATH
ENV PATH="/root/.rover/bin:${PATH}"

# Verify installation
RUN rover --version

USER jenkins
```

**Build and use:**
```bash
# Build the image
docker build -t jenkins-agent-with-rover .

# Use in Jenkinsfile
# agent {
#     docker {
#         image 'jenkins-agent-with-rover'
#     }
# }
```

### Option 4: System-wide Installation (Linux)

For system-wide installation on Linux:

```bash
# Download and install
curl -sSL https://rover.apollo.dev/nix/latest | sh

# Create symlink for system-wide access
sudo ln -s $HOME/.rover/bin/rover /usr/local/bin/rover

# Verify
rover --version
```

### Option 5: Using Jenkins Tool Installer (Advanced)

You can configure Jenkins to automatically install Rover using a tool installer:

1. Go to **Manage Jenkins** → **Global Tool Configuration**
2. Scroll to **Rover** (if plugin exists) or use **Shell Script** tool
3. Configure automatic installation

### Verification

After installation, verify Rover is accessible:

1. **In Jenkins Script Console:**
   - Go to **Manage Jenkins** → **Script Console**
   - Run:
     ```groovy
     def proc = "rover --version".execute()
     proc.waitFor()
     println proc.text
     ```
   - Or use the complete verification script (see [Script Console Guide](./jenkins-script-console-rover.md))

2. **In Build Logs:**
   - Run a test build
   - Check for "Rover CLI not found" message
   - If Rover is installed, you'll see the version number

3. **From Command Line (on Jenkins server):**
   ```bash
   # As Jenkins user
   rover --version
   ```

### Automatic Installation (Fallback)

**Note**: The Jenkinsfile includes automatic installation as a fallback:

```groovy
if ! command -v rover &> /dev/null; then
    echo "Rover CLI not found. Installing..."
    curl -sSL https://rover.apollo.dev/nix/latest | sh
fi
```

This will install Rover during the build if it's not found, but:
- ⚠️ Slows down builds (installation takes time)
- ⚠️ May fail if network access is restricted
- ✅ Works as a fallback if pre-installation isn't possible

### Troubleshooting Installation

**Rover not found in PATH:**
- Check if `~/.rover/bin` is in PATH
- Verify installation location: `ls -la ~/.rover/bin/rover`
- Add to PATH explicitly in Jenkins environment variables

**Permission denied:**
- Ensure Jenkins user has execute permissions: `chmod +x ~/.rover/bin/rover`
- Check file ownership: `ls -la ~/.rover/bin/rover`

**Network issues:**
- Verify agent can reach `https://rover.apollo.dev`
- Check firewall/proxy settings
- Consider downloading Rover binary manually

## Troubleshooting

For detailed troubleshooting, see the [Troubleshooting Guide](./jenkins-troubleshooting.md).

### Common Issues

### Credential Not Found (ERROR: apollo-key)

**Problem**: Build fails immediately with `ERROR: apollo-key`

**Solution**: 
1. Go to **Manage Jenkins** → **Manage Credentials**
2. Add credential with ID: `apollo-key`
3. Or set `APOLLO_KEY` as environment variable

See [Troubleshooting Guide](./jenkins-troubleshooting.md#credential-errors) for details.

### Rover Command Not Found

If you see "Rover CLI not found" in build logs:

1. **Check if Rover is installed:**
   ```bash
   # On Jenkins server/agent
   which rover
   rover --version
   ```

2. **If not installed, install it** (see [Installing Rover CLI on Jenkins](#installing-rover-cli-on-jenkins) above)

3. **If installed but not found:**
   - Check PATH environment variable
   - Add Rover to PATH in Jenkins node configuration
   - Or use full path: `/path/to/.rover/bin/rover`

### Authentication Errors

Verify your `APOLLO_KEY` is set correctly in Jenkins credentials:
- Check Jenkins → Manage Jenkins → Credentials
- Verify the key has proper permissions in Apollo GraphOS

### Schema Check Failures

- Review the build logs for specific schema errors
- Check Apollo GraphOS Studio for schema validation details
- Ensure all federation directives are correct

### Composition Failures

- Verify all subgraphs are published successfully
- Check for schema conflicts between subgraphs
- Review composition errors in Apollo GraphOS Studio

