# Triggering Jenkins on Local Commits

This guide explains how to manually trigger Jenkins builds from your local machine.

## Options Overview

### Option 1: Jenkins CLI Script
Manually trigger builds from command line or scripts.

### Option 2: Manual Trigger
Click "Build Now" in Jenkins UI.

### Option 3: Polling Local Repository
Configure Jenkins to poll your local repository for changes.

## Option 1: Jenkins CLI Script (Recommended)

Use the provided script to trigger builds from command line.

### Setup

1. **Use the trigger script:**

```bash
# Trigger build (default job: reference-architecture)
./scripts/jenkins/trigger-build.sh

# With custom job name
./scripts/jenkins/trigger-build.sh --job reference-architecture-ci

# With authentication
./scripts/jenkins/trigger-build.sh --user admin --token your-token

# With custom URL
./scripts/jenkins/trigger-build.sh --url http://localhost:8080 --job reference-architecture-ci
```

### Environment Variables

You can also set environment variables:

```bash
export JENKINS_URL="http://localhost:8080"
export JENKINS_JOB="reference-architecture-ci"
export JENKINS_USER="admin"
export JENKINS_TOKEN="your-token"

./scripts/jenkins/trigger-build.sh
```

## Option 2: Manual Trigger

Simply click "Build Now" in Jenkins UI.

1. Make your local commits
2. Open Jenkins: `http://localhost:8080`
3. Navigate to your job: `reference-architecture-ci`
4. Click **Build Now**

## Option 3: Polling Local Repository

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
           url: "file:///path/to/reference-architecture"
       ]],
       branches: [[name: '*/workshop-jenkins-ci']]
   ])
   ```

   Or set repository URL to local path:
   ```
   file:///Users/yourname/code/nab-workshop/reference-architecture
   ```

## Troubleshooting

### Jenkins Not Accessible

- Verify Jenkins is running: `curl http://localhost:8080`
- Check firewall/network settings
- Verify Jenkins URL in script or environment variable

### Authentication Errors

- Verify API token is correct
- Check user permissions in Jenkins
- Try without authentication first (if Jenkins allows anonymous builds)

### Build Not Triggering

- Check Jenkins job name matches
- Verify job exists and is enabled
- Check Jenkins logs: `~/.jenkins/logs/jenkins.log`

## Next Steps

1. Choose your preferred option (recommended: Option 1 - CLI Script)
2. Use the CLI script or configure polling
3. Test with a manual trigger
4. Verify build triggers in Jenkins
