#!/bin/bash
set -euo pipefail

# Script 02: Setup Apollo GraphOS Graph
# This script creates an Apollo GraphOS graph and generates API keys

echo "=== Step 02: Setting up Apollo GraphOS Graph ==="

# Load environment variables from .env if it exists
if [ -f .env ]; then
    echo "Loading environment variables from .env..."
    source .env
else
    echo "Warning: .env file not found. Make sure you've created it with your APOLLO_KEY."
    echo "See Step 2 in docs/setup.md for instructions."
fi

# Set defaults only for variables that have reasonable defaults
CLUSTER_PREFIX=${CLUSTER_PREFIX:-"apollo-supergraph-k8s"}

# Validate required variables (don't default to empty strings)
if [[ -z "${APOLLO_KEY:-}" ]]; then
    echo "Error: APOLLO_KEY is required"
    echo "Please set APOLLO_KEY in your .env file or export it:"
    echo "  export APOLLO_KEY=\"your-apollo-personal-api-key\""
    echo ""
    echo "See Step 2 in docs/setup.md for instructions on creating .env"
    exit 1
fi

if [[ -z "${ENVIRONMENT:-}" ]]; then
    echo "Error: ENVIRONMENT is required"
    echo "Please set ENVIRONMENT in your .env file or export it:"
    echo "  export ENVIRONMENT=\"dev\""
    echo ""
    echo "See Step 2 in docs/setup.md for instructions on creating .env"
    exit 1
fi

# Check dependencies
if ! command -v jq &> /dev/null; then
    echo "Error: jq is not installed"
    echo "Please install jq: https://stedolan.github.io/jq/download/"
    exit 1
fi

if ! command -v curl &> /dev/null; then
    echo "Error: curl is not installed"
    exit 1
fi

# Get account ID if not provided
if [[ -z "${ACCOUNT_ID:-}" ]]; then
    echo "Fetching account ID from Apollo GraphOS..."
    ACCOUNT_ARGS=(
        --silent
        --header "x-api-key: $APOLLO_KEY"
        --header 'content-type: application/json'
        --header 'apollographql-client-name: reference-architecture'
        --url 'https://graphql.api.apollographql.com/api/graphql'
        --data '{"query":"{ me { ... on User { memberships { permission account { id } } } } }"}'
    )

    if [[ -n "${HEADER:-}" ]]; then
        ACCOUNT_ARGS+=(--header "$HEADER")
    fi

    ACCOUNT_RESP=$(curl "${ACCOUNT_ARGS[@]}")
    ACCOUNT_COUNT=$(echo $ACCOUNT_RESP | jq -r ".data.me.memberships | length")

    if [[ $ACCOUNT_COUNT > 1 ]]; then
        echo "Apollo Studio returned multiple accounts. Please select one:"
        echo ""
        
        # Display accounts with numbers
        ACCOUNTS=($(echo $ACCOUNT_RESP | jq -r ".data.me.memberships[].account.id"))
        for i in "${!ACCOUNTS[@]}"; do
            echo "  $((i+1)). ${ACCOUNTS[$i]}"
        done
        echo ""
        
        # Prompt for selection
        while true; do
            read -p "Enter the number of the account to use (1-$ACCOUNT_COUNT): " SELECTION
            if [[ "$SELECTION" =~ ^[0-9]+$ ]] && [ "$SELECTION" -ge 1 ] && [ "$SELECTION" -le "$ACCOUNT_COUNT" ]; then
                ACCOUNT_ID="${ACCOUNTS[$((SELECTION-1))]}"
                echo "Selected account: $ACCOUNT_ID"
                break
            else
                echo "Invalid selection. Please enter a number between 1 and $ACCOUNT_COUNT."
            fi
        done
    else
        ACCOUNT_ID=$(echo $ACCOUNT_RESP | jq -r ".data.me.memberships[0].account.id")
    fi
fi

echo "Creating graph on account $ACCOUNT_ID..."

# Create graph
CREATE_ARGS=(
    --silent
    --header "x-api-key: $APOLLO_KEY"
    --header 'content-type: application/json'
    --header 'apollographql-client-name: reference-architecture'
    --url 'https://graphql.api.apollographql.com/api/graphql'
    --data "{\"query\":\"mutation CreateGraph(\$accountId: ID!, \$newServiceId: ID!, \$name: String, \$onboardingArchitecture: OnboardingArchitecture) { newService(accountId: \$accountId, id: \$newServiceId, name: \$name, onboardingArchitecture: \$onboardingArchitecture) { id name apiKeys { token } } }\",\"variables\":{\"accountId\":\"$ACCOUNT_ID\",\"newServiceId\":\"$CLUSTER_PREFIX-$(echo $RANDOM | shasum | head -c 6)\",\"name\":\"Reference Architecture $(date +"%Y-%m-%d")\",\"onboardingArchitecture\":\"SUPERGRAPH\"}}"
)

if [[ -n "${HEADER:-}" ]]; then
    CREATE_ARGS+=(--header "$HEADER")
fi

CREATE_RESP=$(curl "${CREATE_ARGS[@]}")
IS_SUCCESS=$(echo $CREATE_RESP | jq -r ".data.newService")

if [[ "$IS_SUCCESS" == "null" ]]; then
    echo "Error creating graph"
    echo $CREATE_RESP | jq .
    exit 1
fi

# Extract the actual graph ID and name from the response
GRAPH_ID=$(echo $CREATE_RESP | jq -r ".data.newService.id")
GRAPH_NAME=$(echo $CREATE_RESP | jq -r ".data.newService.name")
GRAPH_KEY=$(echo $CREATE_RESP | jq -r ".data.newService.apiKeys[0].token")

echo "Created graph: $GRAPH_NAME (ID: $GRAPH_ID)"

# Create Operator API key
echo "Creating Operator API key..."
CREATE_OPERATOR_KEY_ARGS=(
    --silent
    --header "x-api-key: $APOLLO_KEY"
    --header "apollographql-client-name: reference-architecture"
    --header "apollographql-client-version: 1.0"
    --header 'content-type: application/json'
    --url 'https://api.apollographql.com/api/graphql'
    --data "{\"query\":\"mutation CreateOperatorKey(\$name: String!, \$type: GraphOsKeyType!, \$organizationId: ID!) { organization(id: \$organizationId) { createKey(name: \$name, type: \$type) { id keyName expiresAt token } } }\",\"variables\":{\"name\":\"operator\",\"type\":\"OPERATOR\",\"organizationId\":\"$ACCOUNT_ID\"}}"
)

CREATE_OPERATOR_KEY_RESP=$(curl "${CREATE_OPERATOR_KEY_ARGS[@]}")
OPERATOR_KEY=$(echo $CREATE_OPERATOR_KEY_RESP | jq -r ".data.organization.createKey.token")

if [[ "$OPERATOR_KEY" == "null" ]]; then
    echo "Error creating operator key"
    echo $CREATE_OPERATOR_KEY_RESP | jq .
    exit 1
fi

echo "Operator key created successfully"

# Save to .env file
ENV_FILE=".env"
if [ ! -f "$ENV_FILE" ]; then
    touch "$ENV_FILE"
fi

echo "" >> "$ENV_FILE"
echo "# Apollo GraphOS Configuration (generated by 02-setup-apollo-graph.sh)" >> "$ENV_FILE"
echo "export APOLLO_GRAPH_ID=\"$GRAPH_ID\"" >> "$ENV_FILE"
echo "export APOLLO_KEY=\"$GRAPH_KEY\"" >> "$ENV_FILE"
echo "export OPERATOR_KEY=\"$OPERATOR_KEY\"" >> "$ENV_FILE"
echo "" >> "$ENV_FILE"

echo ""
echo "✓ Apollo GraphOS graph created successfully!"
echo ""
echo "Graph: $GRAPH_NAME"
echo "Graph ID: $GRAPH_ID"
echo "Environment: $ENVIRONMENT"
echo ""
echo "Configuration saved to .env file"
echo ""
echo "Next step: Run 03-setup-cluster.sh to setup the Kubernetes cluster"

