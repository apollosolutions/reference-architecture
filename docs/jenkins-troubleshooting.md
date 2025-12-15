# Jenkins Troubleshooting Guide

Common issues and solutions when running the Jenkins pipeline.

## Credential Errors

### ERROR: apollo-key

**Problem**: `ERROR: apollo-key` in build logs

**Cause**: The credential `apollo-key` is not configured in Jenkins.

**Solution**:

1. **Create the credential:**
   - Go to **Manage Jenkins** → **Manage Credentials**
   - Click on **(global)** → **Add Credentials**
   - Fill in:
     - **Kind**: Secret text
     - **Secret**: Your Apollo GraphOS API key
     - **ID**: `apollo-key` (must match exactly)
     - **Description**: `Apollo GraphOS API Key`
   - Click **OK**

2. **Alternative: Use Environment Variable:**
   - Go to **Manage Jenkins** → **Configure System**
   - Scroll to **Global properties** → **Environment variables**
   - Add:
     - **Name**: `APOLLO_KEY`
     - **Value**: Your Apollo GraphOS API key
   - Click **Save**

3. **Verify:**
   - Run a new build
   - Check that the error is gone

### Credential Not Found Error

**Problem**: Build fails with credential lookup error

**Solution**: The credential ID must match exactly. Check:
- Credential ID is `apollo-key` (case-sensitive)
- Credential is in the correct scope (global or folder)
- You have permission to use the credential

## Workspace Errors

### cleanWs Error

**Problem**: 
```
Required context class hudson.FilePath is missing
Perhaps you forgot to surround the step with a step that provides this, such as: node
```

**Cause**: The `cleanWs` step is trying to run without a workspace context (usually happens when build fails very early).

**Solution**: This is now handled gracefully in the Jenkinsfile. The error is caught and logged as a note. If you see this, it usually means the build failed before creating a workspace, which is expected.

## Environment Variable Errors

### APOLLO_GRAPH_ID Not Set

**Problem**: Build fails with "APOLLO_GRAPH_ID is not set"

**Solution**:

1. **Set in Jenkins:**
   - Go to **Manage Jenkins** → **Configure System**
   - Scroll to **Global properties** → **Environment variables**
   - Add:
     - **Name**: `APOLLO_GRAPH_ID`
     - **Value**: Your Apollo GraphOS graph ID (e.g., `my-graph`)
   - Click **Save**

2. **Or set in job configuration:**
   - Go to your Jenkins job → **Configure**
   - Under **Pipeline** → **Environment**, add:
     ```groovy
     environment {
         APOLLO_GRAPH_ID = 'your-graph-id'
     }
     ```

### ENVIRONMENT Not Set

**Problem**: Build uses wrong environment

**Solution**: Set `ENVIRONMENT` variable (defaults to `dev` if not set):
- **Name**: `ENVIRONMENT`
- **Value**: `dev` (or `prod`, etc.)

## Build Fails Immediately

### No Stages Run

**Problem**: Build fails before any stages execute

**Common Causes**:
1. **Missing credential** - See [Credential Errors](#credential-errors) above
2. **Invalid Jenkinsfile syntax** - Check for syntax errors
3. **Agent/node unavailable** - Check Jenkins node status

**Solution**:
1. Check build logs for the first error
2. Verify credentials are configured
3. Check Jenkins node is online: **Manage Jenkins** → **Manage Nodes and Clouds**

## Rover CLI Errors

### Rover Command Not Found

**Problem**: `rover: command not found` in build logs

**Solution**: 
- The Jenkinsfile automatically installs Rover if not found
- For better performance, pre-install Rover (see [Installing Rover CLI](./jenkins-setup.md#installing-rover-cli-on-jenkins))

### Rover Installation Fails

**Problem**: Rover installation fails during build

**Causes**:
- Network connectivity issues
- Firewall blocking `rover.apollo.dev`
- Insufficient permissions

**Solution**:
1. **Pre-install Rover** (recommended):
   ```bash
   curl -sSL https://rover.apollo.dev/nix/latest | sh
   export PATH="$HOME/.rover/bin:$PATH"
   ```

2. **Check network access:**
   - Verify agent can reach `https://rover.apollo.dev`
   - Check firewall/proxy settings

## Git Checkout Errors

### Checkout Fails

**Problem**: `checkout scm` fails

**Causes**:
- Repository URL incorrect
- Authentication issues
- Branch doesn't exist

**Solution**:
1. **Check repository URL** in job configuration
2. **For local repositories**, use file path: `file:///path/to/repo`
3. **For GitHub**, ensure credentials are configured
4. **Check branch name** matches your branch

## Schema Validation Errors

### Subgraph Check Fails

**Problem**: `rover subgraph check` fails

**Causes**:
- Schema syntax errors
- Breaking changes detected
- Invalid federation directives
- Graph reference incorrect

**Solution**:
1. **Check build logs** for specific error messages
2. **Verify schema.graphql** files are valid
3. **Check APOLLO_GRAPH_REF** format: `graph-id@variant`
4. **Review in Apollo GraphOS Studio** for validation details

### Subgraph Publish Fails

**Problem**: `rover subgraph publish` fails

**Causes**:
- Authentication errors (invalid API key)
- Schema conflicts
- Network issues

**Solution**:
1. **Verify APOLLO_KEY** is correct and has publish permissions
2. **Check schema** for conflicts with other subgraphs
3. **Review Apollo GraphOS Studio** for errors

## Supergraph Compose Errors

### Composition Fails

**Problem**: `rover supergraph compose` fails

**Causes**:
- Not all subgraphs published
- Schema conflicts between subgraphs
- Invalid graph reference

**Solution**:
1. **Verify all subgraphs** published successfully
2. **Check for schema conflicts** in Apollo GraphOS Studio
3. **Review composition errors** in build logs
4. **Ensure graph reference** is correct

## Build Runs But No Output

### Stages Don't Execute

**Problem**: Build completes but no stages run

**Causes**:
- Pipeline syntax error
- Agent/node not available
- Build cancelled

**Solution**:
1. **Check build logs** for errors
2. **Verify agent** is online and available
3. **Check Jenkinsfile syntax** is valid

## Quick Diagnostic Steps

1. **Check credentials:**
   - Manage Jenkins → Manage Credentials
   - Verify `apollo-key` exists

2. **Check environment variables:**
   - Manage Jenkins → Configure System → Environment variables
   - Verify `APOLLO_GRAPH_ID` and `ENVIRONMENT` are set

3. **Check node status:**
   - Manage Jenkins → Manage Nodes and Clouds
   - Verify node is online

4. **Check build logs:**
   - Open build → Console Output
   - Look for first error message

5. **Test Rover manually:**
   - Use Script Console (see [Script Console Guide](./jenkins-script-console-rover.md))
   - Verify Rover is accessible

## Getting Help

If issues persist:

1. **Check build logs** - Look for first error
2. **Verify prerequisites** - All credentials and environment variables set
3. **Test components individually** - Rover, Git, credentials
4. **Review documentation** - See other guides for specific topics

## Common Error Messages

| Error | Cause | Solution |
|-------|-------|----------|
| `ERROR: apollo-key` | Credential not found | Create credential with ID `apollo-key` |
| `APOLLO_GRAPH_ID is not set` | Environment variable missing | Set in Jenkins global environment |
| `rover: command not found` | Rover not installed | Pre-install Rover or let Jenkinsfile install it |
| `Required context class hudson.FilePath is missing` | Workspace context issue | Normal if build fails early, now handled gracefully |
| `Authentication failed` | Invalid API key | Verify APOLLO_KEY is correct |
| `Schema validation failed` | Schema errors | Check schema.graphql files |

