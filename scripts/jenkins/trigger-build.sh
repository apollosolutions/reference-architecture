#!/bin/bash
# Script to manually trigger Jenkins build
# Usage: ./scripts/jenkins/trigger-build.sh [--user username] [--token token]

set -euo pipefail

# Default configuration
JENKINS_URL="${JENKINS_URL:-http://localhost:8080}"
JENKINS_JOB="${JENKINS_JOB:-reference-architecture}"
JENKINS_USER=""
JENKINS_TOKEN=""

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --user)
            JENKINS_USER="$2"
            shift 2
            ;;
        --token)
            JENKINS_TOKEN="$2"
            shift 2
            ;;
        --url)
            JENKINS_URL="$2"
            shift 2
            ;;
        --job)
            JENKINS_JOB="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --user USER      Jenkins username"
            echo "  --token TOKEN    Jenkins API token"
            echo "  --url URL        Jenkins URL (default: http://localhost:8080)"
            echo "  --job JOB        Jenkins job name (default: reference-architecture)"
            echo "  -h, --help       Show this help message"
            echo ""
            echo "Environment variables:"
            echo "  JENKINS_URL      Jenkins URL"
            echo "  JENKINS_JOB      Jenkins job name"
            echo "  JENKINS_USER     Jenkins username"
            echo "  JENKINS_TOKEN    Jenkins API token"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Check if Jenkins is accessible
echo "Checking Jenkins accessibility..."
if ! curl -s --head --fail "${JENKINS_URL}" > /dev/null 2>&1; then
    echo "❌ Error: Jenkins is not accessible at ${JENKINS_URL}"
    echo "   Make sure Jenkins is running and the URL is correct."
    exit 1
fi

echo "✅ Jenkins is accessible"

# Build authentication string if credentials provided
AUTH_STRING=""
if [[ -n "$JENKINS_USER" ]] && [[ -n "$JENKINS_TOKEN" ]]; then
    AUTH_STRING="--user ${JENKINS_USER}:${JENKINS_TOKEN}"
    echo "Using authentication for user: ${JENKINS_USER}"
fi

# Trigger Jenkins build
echo ""
echo "🚀 Triggering Jenkins build: ${JENKINS_JOB}"
echo "   URL: ${JENKINS_URL}"
echo ""

BUILD_URL="${JENKINS_URL}/job/${JENKINS_JOB}/build"

if [[ -n "$AUTH_STRING" ]]; then
    HTTP_CODE=$(curl -s -w "%{http_code}" -o /dev/null ${AUTH_STRING} -X POST "${BUILD_URL}")
else
    HTTP_CODE=$(curl -s -w "%{http_code}" -o /dev/null -X POST "${BUILD_URL}")
fi

if [[ "$HTTP_CODE" == "201" ]] || [[ "$HTTP_CODE" == "200" ]]; then
    echo "✅ Build triggered successfully!"
    echo ""
    echo "View build status:"
    echo "  ${JENKINS_URL}/job/${JENKINS_JOB}/"
    echo ""
    echo "View console output:"
    echo "  ${JENKINS_URL}/job/${JENKINS_JOB}/lastBuild/console"
    echo ""
else
    echo "❌ Failed to trigger build (HTTP ${HTTP_CODE})"
    echo ""
    echo "Troubleshooting:"
    echo "  1. Verify Jenkins is running: curl ${JENKINS_URL}"
    echo "  2. Check job name is correct: ${JENKINS_JOB}"
    echo "  3. If using auth, verify credentials are correct"
    echo "  4. Check Jenkins logs for errors"
    exit 1
fi


