#!/bin/bash
set -euo pipefail

# Script 02a: Refresh Operator API Key
# Creates a new Apollo GraphOS Operator key and updates .env

# Ensure script is run from repository root
if [ ! -d "scripts/minikube" ] || [ ! -f ".env" ]; then
    echo "Error: Run this script from the repository root with .env present"
    echo "  ./scripts/minikube/02a-refresh-operator-key.sh"
    exit 1
fi

echo "=== Refreshing Apollo GraphOS Operator Key ==="

source .env

# Use personal API key for GraphOS API calls (createKey requires org-level permissions)
# If APOLLO_PERSONAL_KEY is set, use it; otherwise APOLLO_KEY (e.g. before graph creation)
API_KEY="${APOLLO_PERSONAL_KEY:-$APOLLO_KEY}"
if [[ -z "$API_KEY" ]]; then
    echo "Error: APOLLO_KEY or APOLLO_PERSONAL_KEY required in .env"
    echo "Use your personal API key from: https://studio.apollographql.com/user-settings/api-keys"
    exit 1
fi

# Get account ID
echo "Fetching account ID..."
ACCOUNT_RESP=$(curl -s \
    -H "x-api-key: $API_KEY" \
    -H "content-type: application/json" \
    -H "apollographql-client-name: reference-architecture" \
    -H "apollographql-client-version: 1.0.0" \
    -d '{"query":"query Me { me { id ... on User { memberships { account { id } } } } }"}' \
    "https://graphql.api.apollographql.com/api/graphql")

ACCOUNT_COUNT=$(echo "$ACCOUNT_RESP" | jq -r ".data.me.memberships | length")

if [[ "$ACCOUNT_COUNT" == "null" || "$ACCOUNT_COUNT" == "0" ]]; then
    echo "Error: Could not fetch account ID. Check that APOLLO_KEY is a valid personal API key."
    echo "Get one from: https://studio.apollographql.com/user-settings/api-keys"
    echo "$ACCOUNT_RESP" | jq .
    exit 1
fi

if [[ "$ACCOUNT_COUNT" -gt 1 ]]; then
    echo "Apollo Studio returned multiple accounts. Please select one:"
    echo ""
    ACCOUNTS=($(echo "$ACCOUNT_RESP" | jq -r ".data.me.memberships[].account.id"))
    for i in "${!ACCOUNTS[@]}"; do
        echo "  $((i+1)). ${ACCOUNTS[$i]}"
    done
    echo ""
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
    ACCOUNT_ID=$(echo "$ACCOUNT_RESP" | jq -r ".data.me.memberships[0].account.id")
fi

# Create operator key
echo "Creating new Operator API key..."
CREATE_RESP=$(curl -s \
    -H "x-api-key: $API_KEY" \
    -H "apollographql-client-name: reference-architecture" \
    -H "apollographql-client-version: 1.0.0" \
    -H "content-type: application/json" \
    -d "{\"query\":\"mutation CreateOperatorKey(\$name: String!, \$type: GraphOsKeyType!, \$organizationId: ID!) { organization(id: \$organizationId) { createKey(name: \$name, type: \$type) { id keyName expiresAt token } } }\",\"variables\":{\"name\":\"operator\",\"type\":\"OPERATOR\",\"organizationId\":\"$ACCOUNT_ID\"}}" \
    "https://api.apollographql.com/api/graphql")

OPERATOR_KEY=$(echo "$CREATE_RESP" | jq -r ".data.organization.createKey.token")

if [[ "$OPERATOR_KEY" == "null" || -z "$OPERATOR_KEY" ]]; then
    echo "Error: Could not create operator key"
    echo "$CREATE_RESP" | jq .
    exit 1
fi

echo "Operator key created successfully"

# Update .env - replace existing OPERATOR_KEY line or add if missing
if grep -q '^export OPERATOR_KEY=' .env; then
    if [[ "$(uname)" == "Darwin" ]]; then
        sed -i '' "s|^export OPERATOR_KEY=.*|export OPERATOR_KEY=\"$OPERATOR_KEY\"|" .env
    else
        sed -i "s|^export OPERATOR_KEY=.*|export OPERATOR_KEY=\"$OPERATOR_KEY\"|" .env
    fi
    echo "Updated OPERATOR_KEY in .env"
else
    echo "" >> .env
    echo "# Operator key (refreshed by 02a-refresh-operator-key.sh)" >> .env
    echo "export OPERATOR_KEY=\"$OPERATOR_KEY\"" >> .env
    echo "Added OPERATOR_KEY to .env"
fi

# Update Kubernetes secret if cluster is running
if kubectl get secret apollo-api-key -n apollo-operator &>/dev/null; then
    echo "Updating operator secret in Kubernetes..."
    kubectl create secret generic apollo-api-key \
        --from-literal="APOLLO_KEY=$OPERATOR_KEY" \
        -n apollo-operator \
        --dry-run=client -o yaml | kubectl apply -f -
    echo "Restarting operator to pick up new key..."
    kubectl rollout restart deployment/apollo-operator -n apollo-operator
    kubectl rollout status deployment/apollo-operator -n apollo-operator --timeout=120s
fi

echo ""
echo "✓ Done. OPERATOR_KEY updated in .env"
echo ""
