pipeline {
    agent any

    environment {
        // Apollo GraphOS configuration
        // Note: APOLLO_KEY will be set in Validate Environment stage to handle missing credentials gracefully
        APOLLO_GRAPH_REF = "${env.APOLLO_GRAPH_ID}@${env.ENVIRONMENT ?: 'dev'}"
        ENVIRONMENT = "${env.ENVIRONMENT ?: 'dev'}"
        
        // Subgraphs to process (comma-separated, default: checkout only)
        // Set via Jenkins environment variable or build parameter
        // Example: checkout,discovery,inventory
        SUBGRAPHS = "${env.SUBGRAPHS ?: 'checkout'}"
        
        // Target branch for publishing (publish only on merges to this branch)
        // Default: workshop-jenkins-ci
        PUBLISH_BRANCH = "${env.PUBLISH_BRANCH ?: 'workshop-jenkins-ci'}"
    }

    options {
        // Keep build history
        buildDiscarder(logRotator(numToKeepStr: '50'))
        
        // Timeout after 30 minutes
        timeout(time: 30, unit: 'MINUTES')
        
        // Add timestamps to console output
        timestamps()
    }

    stages {
        stage('Checkout') {
            steps {
                script {
                    echo "Checking out code from ${env.GIT_BRANCH ?: 'current branch'}"
                    checkout scm
                }
            }
        }

        stage('Validate Environment') {
            steps {
                script {
                    echo "Validating environment configuration..."
                    
                    // Try to get APOLLO_KEY from credentials if not already set
                    try {
                        if (!env.APOLLO_KEY) {
                            def apolloKeyCred = credentials('apollo-key')
                            env.APOLLO_KEY = apolloKeyCred
                        }
                    } catch (Exception e) {
                        error("APOLLO_KEY credential 'apollo-key' not found. Please configure it in Jenkins:\n" +
                              "1. Go to Manage Jenkins → Manage Credentials\n" +
                              "2. Add credential with ID: apollo-key\n" +
                              "3. Or set APOLLO_KEY as environment variable")
                    }
                    
                    if (!env.APOLLO_KEY || env.APOLLO_KEY.trim().isEmpty()) {
                        error("APOLLO_KEY is not set. Please configure it in Jenkins credentials (ID: apollo-key) or as environment variable.")
                    }
                    
                    if (!env.APOLLO_GRAPH_ID) {
                        error("APOLLO_GRAPH_ID is not set. Please set it as an environment variable in Jenkins:\n" +
                              "Manage Jenkins → Configure System → Environment variables")
                    }
                    
                    echo "Environment: ${ENVIRONMENT}"
                    echo "Graph Reference: ${APOLLO_GRAPH_REF}"
                    echo "Publish Branch: ${PUBLISH_BRANCH}"
                    
                    // Detect current branch
                    env.CURRENT_BRANCH = sh(
                        script: 'git rev-parse --abbrev-ref HEAD',
                        returnStdout: true
                    ).trim()
                    
                    // Normalize branch name (remove origin/ prefix if present)
                    env.CURRENT_BRANCH = env.CURRENT_BRANCH.replaceAll('^origin/', '')
                    
                    // Check if this is a merge commit (has multiple parents)
                    def parentCount = sh(
                        script: 'git cat-file -p HEAD | grep "^parent " | wc -l | tr -d " "',
                        returnStdout: true
                    ).trim()
                    
                    // Also check commit message for merge indicators
                    def commitMsg = sh(
                        script: 'git log -1 --pretty=%B',
                        returnStdout: true
                    ).trim()
                    
                    // Check if MERGE_HEAD exists (for in-progress merges)
                    def mergeHeadExists = sh(
                        script: 'test -f .git/MERGE_HEAD && echo "true" || echo "false"',
                        returnStdout: true
                    ).trim()
                    
                    // Determine if merge: multiple parents OR merge message OR MERGE_HEAD exists
                    def isMergeCommit = (parentCount.toInteger() > 1 || 
                                        commitMsg.toLowerCase().contains('merge') ||
                                        mergeHeadExists == "true")
                    env.IS_MERGE = isMergeCommit ? "true" : "false"
                    
                    // Determine if we should publish (merge to publish branch)
                    env.SHOULD_PUBLISH = "false"
                    if (env.IS_MERGE == "true" && env.CURRENT_BRANCH == PUBLISH_BRANCH) {
                        env.SHOULD_PUBLISH = "true"
                    }
                    
                    echo "Current Branch: ${env.CURRENT_BRANCH}"
                    echo "Publish Branch: ${PUBLISH_BRANCH}"
                    echo "Commit Parents: ${parentCount}"
                    echo "Is Merge Commit: ${env.IS_MERGE}"
                    echo "Should Publish: ${env.SHOULD_PUBLISH}"
                    
                    // Verify Rover is installed
                    sh '''
                        if ! command -v rover &> /dev/null; then
                            echo "Rover CLI not found. Installing..."
                            curl -sSL https://rover.apollo.dev/nix/latest | sh
                        fi
                        rover --version
                    '''
                }
            }
        }

        stage('Subgraph Check') {
            steps {
                script {
                    def subgraphs = SUBGRAPHS.split(',').collect { it.trim() }
                    echo "Processing ${subgraphs.size()} subgraph(s): ${subgraphs.join(', ')}"
                    
                    for (subgraph in subgraphs) {
                        stage("Check ${subgraph}") {
                            runRoverCheck(subgraph)
                        }
                    }
                }
            }
        }

        stage('Subgraph Publish') {
            when {
                expression { env.SHOULD_PUBLISH == "true" }
            }
            steps {
                script {
                    echo "✅ Merge detected to ${PUBLISH_BRANCH} branch - Publishing subgraphs..."
                    def subgraphs = SUBGRAPHS.split(',').collect { it.trim() }
                    echo "Publishing ${subgraphs.size()} subgraph(s): ${subgraphs.join(', ')}"
                    
                    for (subgraph in subgraphs) {
                        stage("Publish ${subgraph}") {
                            runRoverPublish(subgraph)
                        }
                    }
                }
            }
        }

        stage('Skip Publish') {
            when {
                expression { env.SHOULD_PUBLISH == "false" }
            }
            steps {
                script {
                    echo "⏭️  Skipping publish (not a merge to ${PUBLISH_BRANCH} branch)"
                    echo "   Current branch: ${env.CURRENT_BRANCH}"
                    echo "   Is merge: ${env.IS_MERGE}"
                    echo "   Publish branch: ${PUBLISH_BRANCH}"
                }
            }
        }

        stage('Supergraph Compose') {
            when {
                expression { env.SHOULD_PUBLISH == "true" }
            }
            steps {
                script {
                    echo "Composing supergraph from all subgraphs..."
                    
                    // Check if config file exists, use it if available
                    def configFlag = ""
                    if (fileExists("scripts/jenkins/supergraph-config.yaml")) {
                        configFlag = "--config scripts/jenkins/supergraph-config.yaml"
                    }
                    
                    sh """
                        rover supergraph compose \\
                            ${configFlag} \\
                            --output supergraph-${ENVIRONMENT}.graphql \\
                            ${APOLLO_GRAPH_REF}
                    """
                    
                    echo "Supergraph composed successfully!"
                    sh "ls -lh supergraph-${ENVIRONMENT}.graphql"
                    
                    // Archive the composed supergraph
                    archiveArtifacts artifacts: "supergraph-${ENVIRONMENT}.graphql", fingerprint: true
                }
            }
        }
    }

    post {
        success {
            script {
                if (env.SHOULD_PUBLISH == "true") {
                    echo "✅ All checks passed and subgraphs published successfully!"
                    echo "Supergraph composed and available at: supergraph-${ENVIRONMENT}.graphql"
                } else {
                    echo "✅ All checks passed!"
                    echo "⏭️  Publishing skipped (not a merge to ${PUBLISH_BRANCH} branch)"
                }
            }
        }
        failure {
            script {
                echo "❌ Build failed. Check the logs above for details."
            }
        }
        always {
            script {
                // Only clean workspace if we have a workspace context
                try {
                    cleanWs()
                } catch (Exception e) {
                    echo "Note: Could not clean workspace (this is normal if build failed early)"
                }
            }
        }
    }
}

// Helper function to run rover subgraph check
def runRoverCheck(String subgraphName) {
    echo "Checking ${subgraphName} subgraph..."
    
    sh """
        cd subgraphs/${subgraphName}
        rover subgraph check ${APOLLO_GRAPH_REF} \\
            --name ${subgraphName} \\
            --schema schema.graphql
    """
    
    echo "✅ ${subgraphName} subgraph check passed"
}

// Helper function to run rover subgraph publish
def runRoverPublish(String subgraphName) {
    echo "Publishing ${subgraphName} subgraph..."
    
    // Determine subgraph URL (adjust based on your deployment)
    def subgraphUrl = "http://graphql.${subgraphName}.svc.cluster.local:4001"
    
    sh """
        cd subgraphs/${subgraphName}
        rover subgraph publish ${APOLLO_GRAPH_REF} \\
            --name ${subgraphName} \\
            --schema schema.graphql \\
            --routing-url ${subgraphUrl}
    """
    
    echo "✅ ${subgraphName} subgraph published successfully"
}

