# Manual Jenkins Setup Instructions

This guide walks you through setting up Jenkins locally and configuring it to run Rover commands for this reference architecture.

## Step 1: Install Jenkins

### macOS (using Homebrew)

```bash
brew install jenkins-lts
```

Or download from [Jenkins website](https://www.jenkins.io/download/)

### Start Jenkins

```bash
brew services start jenkins-lts
```

Or run directly:
```bash
jenkins-lts
```

Jenkins will start on `http://localhost:8080`

### Initial Setup

1. Open `http://localhost:8080` in your browser
2. You'll see an "Unlock Jenkins" screen
3. Get the initial admin password:
   ```bash
   cat ~/.jenkins/secrets/initialAdminPassword
   ```
4. Paste the password and click "Continue"
5. Install suggested plugins
6. Create an admin user (or skip to use admin account)
7. Click "Save and Finish"

## Step 2: Install Required Plugins

1. Go to **Manage Jenkins** → **Manage Plugins**
2. Click on **Available** tab
3. Search and install:
   - **Pipeline** (usually pre-installed)
   - **Git** (for Git integration)
   - **GitHub** (optional, for GitHub webhooks)
   - **Credentials Binding** (for secure credential management)
   - **Timestamper** (for build logs with timestamps)

4. Click **Install without restart** or **Download now and install after restart**

## Step 3: Install Rover CLI on Jenkins Agent

Jenkins needs Rover CLI installed. The Jenkinsfile will automatically install Rover if it's not found, but **pre-installing is recommended** for better performance.

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

If you're using remote Jenkins agents:

1. **SSH into the agent:**
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

4. **Configure in Jenkins:**
   - Go to **Manage Jenkins** → **Manage Nodes and Clouds**
   - Select your agent node
   - Under **Node Properties**, add environment variable:
     - **Name**: `PATH`
     - **Value**: `$HOME/.rover/bin:$PATH`

### Option 3: Docker Agent

If using Docker agents, create a custom Docker image:

**Create `Dockerfile`:**
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

**Build the image:**
```bash
docker build -t jenkins-agent-with-rover .
```

**Use in Jenkinsfile:**
```groovy
agent {
    docker {
        image 'jenkins-agent-with-rover'
    }
}
```

### Option 4: Automatic Installation (Fallback)

**Note**: The Jenkinsfile automatically installs Rover if it's not found during the build. This works but:
- ⚠️ Slows down each build (installation takes ~30 seconds)
- ⚠️ Requires network access during build
- ✅ Useful as a fallback if pre-installation isn't possible

### Verify Installation

After installation, verify Rover works:

1. **From command line:**
   ```bash
   rover --version
   ```

2. **In Jenkins:**
   - Go to **Manage Jenkins** → **Script Console**
   - Run: `sh 'rover --version'`

3. **In a test build:**
   - Run a build and check logs
   - Should see Rover version, not "installing..." message

For more detailed installation instructions, see the [Jenkins Setup Guide](./jenkins-setup.md#installing-rover-cli-on-jenkins).

## Step 4: Configure Credentials

### Add Apollo GraphOS API Key

1. Go to **Manage Jenkins** → **Manage Credentials**
2. Click on **(global)** → **Add Credentials**
3. Fill in:
   - **Kind**: Secret text
   - **Secret**: Your Apollo GraphOS API key
   - **ID**: `apollo-key`
   - **Description**: `Apollo GraphOS API Key`
4. Click **OK**

### Add Environment Variables (Optional)

1. Go to **Manage Jenkins** → **Configure System**
2. Scroll to **Global properties**
3. Check **Environment variables**
4. Add:
   - `APOLLO_GRAPH_ID`: Your Apollo GraphOS graph ID
   - `ENVIRONMENT`: `dev` (or your environment name)
5. Click **Save**

## Step 5: Create Jenkins Job

### Option 1: Using Jenkinsfile (Recommended)

1. Go to **New Item**
2. Enter job name: `reference-architecture`
3. Select **Pipeline**
4. Click **OK**
5. In **Pipeline** section:
   - **Definition**: Pipeline script from SCM
   - **SCM**: Git
   - **Repository URL**: Your repository URL (or local path)
   - **Branch**: `*/main` or `*/master` (or your default branch)
   - **Script Path**: `Jenkinsfile`
6. Click **Save**

### Option 2: Manual Pipeline Script

1. Go to **New Item**
2. Enter job name: `reference-architecture`
3. Select **Pipeline**
4. Click **OK**
5. In **Pipeline** section:
   - **Definition**: Pipeline script
   - Paste the contents of `Jenkinsfile` from the repository
6. Click **Save**

## Step 6: Configure GitHub Integration (Optional)

### For GitHub Webhooks

1. In your GitHub repository, go to **Settings** → **Webhooks**
2. Click **Add webhook**
3. Configure:
   - **Payload URL**: `http://your-jenkins-url:8080/github-webhook/`
   - **Content type**: `application/json`
   - **Events**: Select **Just the push event** or **Let me select individual events**
     - Check: **Pushes**
     - Check: **Pull requests**
4. Click **Add webhook**

### For Local Testing (Manual Triggers)

You can manually trigger builds:
1. Go to your Jenkins job
2. Click **Build Now**

## Step 7: Test the Pipeline

1. Go to your Jenkins job: `reference-architecture`
2. Click **Build Now**
3. Click on the build number to view progress
4. Click **Console Output** to see logs

### Expected Output

You should see:
- ✅ Checkout stage completes
- ✅ Environment validation passes
- ✅ All subgraph checks pass (in parallel)
- ✅ All subgraph publishes succeed (in parallel)
- ✅ Supergraph compose completes
- ✅ Build succeeds

## Step 8: Configure Build Triggers (Optional)

### Poll SCM (Check for changes periodically)

1. In your Jenkins job, click **Configure**
2. Scroll to **Build Triggers**
3. Check **Poll SCM**
4. Enter schedule: `H/5 * * * *` (every 5 minutes)
5. Click **Save**

### GitHub Webhook (Automatic on push)

1. In your Jenkins job, click **Configure**
2. Scroll to **Build Triggers**
3. Check **GitHub hook trigger for GITScm polling**
4. Click **Save**

## Troubleshooting

### Jenkins Can't Find Rover

**Problem**: `rover: command not found`

**Solution**: 
1. **Install Rover** (see Step 3 above for detailed instructions):
   ```bash
   curl -sSL https://rover.apollo.dev/nix/latest | sh
   export PATH="$HOME/.rover/bin:$PATH"
   ```

2. **Verify installation:**
   ```bash
   rover --version
   ```

3. **If using remote agents**, install on the agent node and configure PATH in Jenkins node settings

4. **The Jenkinsfile will auto-install Rover** if not found, but pre-installing is recommended for better performance

For more detailed installation instructions, see the [Jenkins Setup Guide](./jenkins-setup.md#installing-rover-cli-on-jenkins).

### Authentication Errors

**Problem**: `Authentication failed` or `Invalid API key`

**Solution**:
- Verify `APOLLO_KEY` credential is set correctly
- Check the credential ID matches `apollo-key` in Jenkinsfile
- Verify the API key has proper permissions in Apollo GraphOS

### Git Checkout Fails

**Problem**: `Could not resolve hostname` or authentication errors

**Solution**:
- For local repositories, use file path: `file:///path/to/repo`
- For GitHub, ensure credentials are configured
- Check Jenkins → Manage Jenkins → Configure System → Git

### Subgraph Check/Publish Fails

**Problem**: Schema validation errors

**Solution**:
- Check build logs for specific schema errors
- Verify `APOLLO_GRAPH_REF` is correct (format: `graph-id@variant`)
- Ensure all subgraphs are registered in Apollo GraphOS
- Check schema.graphql files are valid

### Supergraph Compose Fails

**Problem**: Composition errors

**Solution**:
- Verify all subgraphs published successfully
- Check for schema conflicts in Apollo GraphOS Studio
- Review composition errors in build logs
- Ensure supergraph-config.yaml exists (if using config file)

## Advanced Configuration

### Multiple Environments

To run builds for different environments:

1. Create separate Jenkins jobs:
   - `reference-architecture-dev`
   - `reference-architecture-prod`

2. Or use Jenkins parameters:
   - In Jenkinsfile, add: `parameters { choice(name: 'ENVIRONMENT', choices: ['dev', 'prod'], description: 'Environment') }`
   - Use `${params.ENVIRONMENT}` instead of `${env.ENVIRONMENT}`

### Custom Supergraph Config

Create `scripts/jenkins/supergraph-config.yaml` if you need custom composition settings:

```yaml
federation_version: "2.0"
subgraphs:
  - name: checkout
    routing_url: http://graphql.checkout.svc.cluster.local:4001
  # ... other subgraphs
```

### Notifications

Add email/Slack notifications in the `post` section of Jenkinsfile:

```groovy
post {
    success {
        emailext (
            subject: "✅ Build Successful: ${env.JOB_NAME} #${env.BUILD_NUMBER}",
            body: "Build succeeded!",
            to: "team@example.com"
        )
    }
    failure {
        emailext (
            subject: "❌ Build Failed: ${env.JOB_NAME} #${env.BUILD_NUMBER}",
            body: "Build failed. Check logs.",
            to: "team@example.com"
        )
    }
}
```

## Next Steps

- Set up webhooks for automatic builds
- Configure notifications (email, Slack, etc.)
- Add additional stages (tests, deployments, etc.)
- Set up build promotion for production deployments

