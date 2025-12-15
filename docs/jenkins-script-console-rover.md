# Using Jenkins Script Console to Verify Rover Installation

This guide shows how to check and install Rover CLI using the Jenkins Script Console.

## The Problem

In the Script Console, you can't use `sh` the same way as in a Jenkinsfile. The error you saw:
```
groovy.lang.MissingMethodException: No signature of method: Script1.sh() is applicable
```

This happens because `sh` is a Jenkins pipeline step, not a direct Groovy method in Script Console.

## Correct Way to Check Rover in Script Console

### Option 1: Check if Rover Exists (Simple)

```groovy
def proc = "/var/jenkins_home/.rover/bin/rover --version".execute()
proc.waitFor()
println "Exit code: ${proc.exitValue()}"
println "Output: ${proc.text}"
```

### Option 2: Check Multiple Locations

```groovy
def roverPaths = [
    "/var/jenkins_home/.rover/bin/rover",
    "/root/.rover/bin/rover",
    "/usr/local/bin/rover",
    "/usr/bin/rover"
]

roverPaths.each { path ->
    def file = new File(path)
    if (file.exists()) {
        println "✅ Found Rover at: ${path}"
        def proc = "${path} --version".execute()
        proc.waitFor()
        println "   Version: ${proc.text.trim()}"
    } else {
        println "❌ Not found: ${path}"
    }
}
```

### Option 3: Check PATH Environment Variable

```groovy
def env = System.getenv()
println "PATH: ${env.PATH}"
println "HOME: ${env.HOME}"

// Check if rover is in PATH
def proc = "which rover".execute()
proc.waitFor()
if (proc.exitValue() == 0) {
    println "✅ Rover found in PATH: ${proc.text.trim()}"
} else {
    println "❌ Rover not found in PATH"
}
```

## Installing Rover via Script Console

### Install Rover (if not found)

```groovy
def roverPath = "/var/jenkins_home/.rover/bin/rover"
def roverDir = new File("/var/jenkins_home/.rover/bin")

// Check if already installed
if (new File(roverPath).exists()) {
    println "✅ Rover already installed at: ${roverPath}"
    def proc = "${roverPath} --version".execute()
    proc.waitFor()
    println "Version: ${proc.text.trim()}"
} else {
    println "Installing Rover..."
    
    // Create directory if it doesn't exist
    roverDir.mkdirs()
    
    // Install Rover
    def installProc = "curl -sSL https://rover.apollo.dev/nix/latest | sh".execute()
    installProc.waitFor()
    
    if (installProc.exitValue() == 0) {
        println "✅ Rover installed successfully"
        
        // Verify installation
        def verifyProc = "${roverPath} --version".execute()
        verifyProc.waitFor()
        println "Version: ${verifyProc.text.trim()}"
    } else {
        println "❌ Installation failed"
        println "Error: ${installProc.err.text}"
    }
}
```

## Setting PATH in Jenkins (Permanent Solution)

The Script Console is for testing. To make Rover available permanently, configure it properly:

### Method 1: Add to Jenkins Global Environment Variables

1. Go to **Manage Jenkins** → **Configure System**
2. Scroll to **Global properties**
3. Check **Environment variables**
4. Add:
   - **Name**: `PATH`
   - **Value**: `/var/jenkins_home/.rover/bin:${PATH}`

### Method 2: Add to Node Configuration

1. Go to **Manage Jenkins** → **Manage Nodes and Clouds**
2. Select your node (usually "master" or "built-in")
3. Click **Configure**
4. Under **Node Properties**, check **Environment variables**
5. Add:
   - **Name**: `PATH`
   - **Value**: `/var/jenkins_home/.rover/bin:${PATH}`

### Method 3: Install System-Wide

```groovy
// Run this in Script Console as root/admin
def installScript = """
    curl -sSL https://rover.apollo.dev/nix/latest | sh
    ln -s \$HOME/.rover/bin/rover /usr/local/bin/rover
""".trim()

def proc = installScript.execute()
proc.waitFor()
println "Exit code: ${proc.exitValue()}"
println "Output: ${proc.text}"
```

## Complete Verification Script

Run this in Script Console to check everything:

```groovy
println "=== Rover Installation Check ==="
println ""

// Check environment
def env = System.getenv()
println "HOME: ${env.HOME}"
println "USER: ${env.USER}"
println "PATH: ${env.PATH}"
println ""

// Check common Rover locations
def locations = [
    "/var/jenkins_home/.rover/bin/rover",
    "${env.HOME}/.rover/bin/rover",
    "/root/.rover/bin/rover",
    "/usr/local/bin/rover"
]

def found = false
locations.each { path ->
    def file = new File(path)
    if (file.exists() && file.canExecute()) {
        println "✅ Found: ${path}"
        def proc = "${path} --version".execute()
        proc.waitFor()
        if (proc.exitValue() == 0) {
            println "   Version: ${proc.text.trim()}"
            found = true
        }
    }
}

if (!found) {
    println "❌ Rover not found in common locations"
    println ""
    println "To install:"
    println "  curl -sSL https://rover.apollo.dev/nix/latest | sh"
    println ""
    println "Then add to PATH in Jenkins:"
    println "  Manage Jenkins → Configure System → Environment variables"
    println "  PATH = \${HOME}/.rover/bin:\${PATH}"
} else {
    println ""
    println "✅ Rover is installed and accessible"
}
```

## Quick Test: Check Rover Version

If Rover is installed and in PATH:

```groovy
def proc = "rover --version".execute()
proc.waitFor()
if (proc.exitValue() == 0) {
    println "✅ Rover version: ${proc.text.trim()}"
} else {
    println "❌ Rover not found or error: ${proc.err.text}"
}
```

## Troubleshooting

### "command not found" in Script Console but works in terminal

This means PATH isn't set correctly for Jenkins. Use one of the PATH configuration methods above.

### Permission denied

```groovy
// Check permissions
def roverFile = new File("/var/jenkins_home/.rover/bin/rover")
if (roverFile.exists()) {
    println "Exists: ${roverFile.exists()}"
    println "Readable: ${roverFile.canRead()}"
    println "Executable: ${roverFile.canExecute()}"
    println "Permissions: ${roverFile.permissions()}"
}
```

### Installation fails

Check network connectivity:

```groovy
def proc = "curl -I https://rover.apollo.dev/nix/latest".execute()
proc.waitFor()
println "HTTP Status: ${proc.exitValue() == 0 ? 'OK' : 'Failed'}"
```

## Next Steps

After verifying Rover is installed:

1. **Configure PATH** in Jenkins (see methods above)
2. **Test in a build** - Run a test build and check logs
3. **Verify in Jenkinsfile** - The Jenkinsfile should detect Rover automatically

For more information, see the [Jenkins Setup Guide](./jenkins-setup.md#installing-rover-cli-on-jenkins).


