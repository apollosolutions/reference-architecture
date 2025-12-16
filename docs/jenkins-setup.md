# Jenkins CI/CD Setup Guide

This guide explains how to set up Jenkins for automated CI/CD with Apollo Rover commands for this reference architecture.

## Overview

Jenkins will automatically:

1. **Detect changed subgraphs** by analyzing git diffs
2. **Validate** changed subgraph schemas using `rover subgraph check`
3. **Publish** changed subgraph schemas to Apollo GraphOS using `rover subgraph publish`
4. **Compose** supergraph (via separate compose pipeline)

## Prerequisites

Before setting up Jenkins, ensure you have:

1. **Apollo GraphOS Account** with:
   - Personal API Key (for initial setup)
   - Graph ID configured
   - All subgraphs registered in GraphOS

2. **Environment Variables** to configure:
   - `APOLLO_KEY`: Your Apollo GraphOS API key
   - `APOLLO_GRAPH_ID`: Your graph ID
   - `ENVIRONMENT`: Environment name (defaults to `workshop-jenkins-ci`)

3. **Rover CLI** installed on the Jenkins agent/node
   
   > **Note**: The Jenkinsfile includes automatic Rover installation, but pre-installing it is recommended for better performance.

## Step 1: Install Jenkins

### macOS (using Homebrew)

```bash
brew install jenkins-lts
brew services start jenkins-lts
```

Or download from [Jenkins website](https://www.jenkins.io/download/)

Jenkins will start on `http://localhost:8080`

### Initial Setup

1. Open `http://localhost:8080` in your browser
2. Get the initial admin password:
   ```bash
   cat ~/.jenkins/secrets/initialAdminPassword
   ```
3. Paste the password and click "Continue"
4. Install suggested plugins
5. Create an admin user (or skip to use admin account)
6. Click "Save and Finish"

## Step 2: Install Required Plugins

1. Go to **Manage Jenkins** → **Manage Plugins**
2. Click on **Available** tab
3. Search and install:
   - **Pipeline** (usually pre-installed)
   - **Git** (for Git integration)
   - **GitHub** (optional, for GitHub webhooks)
   - **GitHub Custom Notification Context SCM Behaviour** (for customizing GitHub status check names)
   - **Credentials Binding** (for secure credential management)
   - **Timestamper** (for build logs with timestamps)

4. Click **Install without restart** or **Download now and install after restart**

## Step 3: Install Rover CLI

The Jenkinsfile automatically installs Rover if it's not found, but **pre-installing is recommended** for better performance.

### Option 1: Install on Jenkins Server (Local Installation)

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

**If Jenkins runs as a different user** (e.g., `jenkins` user):

```bash
# Switch to Jenkins user
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

### Automatic Installation (Fallback)

**Note**: The Jenkinsfile includes automatic installation as a fallback:

```groovy
if ! command -v rover &> /dev/null; then
    echo "Rover CLI not found. Installing..."
    curl -sSL https://rover.apollo.dev/nix/latest | sh -s -- --force
fi
```

This will install Rover during the build if it's not found, but:
- ⚠️ Slows down builds (installation takes time)
- ⚠️ May fail if network access is restricted
- ✅ Works as a fallback if pre-installation isn't possible

## Step 4: Configure Credentials

### Add Apollo GraphOS API Key

1. Go to **Manage Jenkins** → **Manage Credentials**
2. Click on **(global)** → **Add Credentials**
3. Fill in:
   - **Kind**: Secret text
   - **Secret**: Your Apollo GraphOS API key
   - **ID**: `apollo-key` (must match exactly)
   - **Description**: `Apollo GraphOS API Key`
4. Click **OK**

### Add Environment Variables

1. Go to **Manage Jenkins** → **Configure System**
2. Scroll to **Global properties**
3. Check **Environment variables**
4. Add:
   - `APOLLO_GRAPH_ID`: Your Apollo GraphOS graph ID
   - `ENVIRONMENT`: `workshop-jenkins-ci` (or your environment name)
5. Click **Save**

## Step 5: Create Jenkins Jobs

### Main CI Pipeline (Jenkinsfile.ci)

1. Go to **New Item**
2. Enter job name: `reference-architecture-ci`
3. Select **Pipeline**
4. Click **OK**
5. In **Pipeline** section:
   - **Definition**: Pipeline script from SCM
   - **SCM**: Git
   - **Repository URL**: Your repository URL (or local path)
   - **Branch**: `*/workshop-jenkins-ci`
   - **Script Path**: `Jenkinsfile.ci`
6. Click **Save**

### Pull Request Pipeline (Jenkinsfile.pr)

1. Go to **New Item**
2. Enter job name: `reference-architecture-pr`
3. Select **Multibranch Pipeline** (recommended) or **Pipeline**
4. Click **OK**
5. Configure branch source:
   - **Branch Sources**: Add GitHub/Git source
   - **Repository**: Your repository
   - **Behaviors**: Add "Discover pull requests"
   - **Script Path**: `Jenkinsfile.pr`
6. Click **Save**

### Parameterized Jobs (Optional)

For manual testing, create jobs from:
- **Jenkinsfile.check**: Single subgraph check
- **Jenkinsfile.publish**: Single subgraph publish
- **Jenkinsfile.compose**: Supergraph composition

## Step 6: Configure Build Triggers

### SCM Polling (for CI Pipeline)

1. In your Jenkins job, click **Configure**
2. Scroll to **Build Triggers**
3. Check **Poll SCM**
4. Enter schedule: `H/2 * * * *` (every 2 minutes)
5. Click **Save**

### GitHub Webhooks (Recommended for Production)

1. In your GitHub repository, go to **Settings** → **Webhooks**
2. Click **Add webhook**
3. Configure:
   - **Payload URL**: `http://your-jenkins-url:8080/github-webhook/`
   - **Content type**: `application/json`
   - **Events**: Select **Just the push event** or **Let me select individual events**
     - Check: **Pushes**
     - Check: **Pull requests**
4. Click **Add webhook**

## Step 7: Test the Pipeline

1. Go to your Jenkins job: `reference-architecture-ci`
2. Click **Build Now**
3. Click on the build number to view progress
4. Click **Console Output** to see logs

### Expected Output

You should see:
- ✅ Checkout stage completes
- ✅ Changed subgraphs detected
- ✅ Environment validation passes
- ✅ Changed subgraph checks pass (in parallel)
- ✅ Changed subgraph publishes succeed
- ✅ Build succeeds

## How Changed Subgraph Detection Works

The pipeline automatically detects which subgraphs have changed by:

1. Comparing the current commit with the previous commit (or target branch for PRs)
2. Analyzing changed files in the `subgraphs/` directory
3. Extracting unique subgraph names from file paths
4. Processing only the changed subgraphs

**Example**: If you modify `subgraphs/checkout/schema.graphql` and `subgraphs/inventory/src/index.ts`, the pipeline will process both `checkout` and `inventory` subgraphs.

## Environment-Specific Behavior

The Jenkins pipeline respects the `ENVIRONMENT` variable:

- **workshop-jenkins-ci**: Default for CI pipeline (uses `@workshop-jenkins-ci` variant)
- **dev**: Development environment (uses `@dev` variant)
- **prod**: Production environment (uses `@prod` variant)

Each environment publishes to its own variant, allowing parallel development and testing.

## Next Steps

- Set up webhooks for automatic builds
- Configure notifications (email, Slack)
- Test with a real commit
- Review build logs to verify everything works

For more information, see:
- [Quick Reference Guide](./jenkins-quick-reference.md)
- [Local Triggers Guide](./jenkins-local-triggers.md) (for local commit triggers)
