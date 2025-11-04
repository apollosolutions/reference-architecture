#/bin/bash
set -euo pipefail

APOLLO_KEY=${APOLLO_KEY:-""}
CLUSTER_PREFIX=${CLUSTER_PREFIX:-"apollo-supergraph-k8s"}
ACCOUNT_ID=${ACCOUNT_ID:-""}
GRAPH_ID=$CLUSTER_PREFIX-$(echo $RANDOM | shasum | head -c 6)
HEADER=${HEADER:-""}
VARIANTS=("dev" "prod")

if [[ "$APOLLO_KEY" == "" ]]; then
  echo "Must provide APOLLO_KEY in environment" 1>&2
  exit 1
fi

if [[ $(which jq) == "" ]]; then
  echo "please install jq before continuing: https://stedolan.github.io/jq/"
  exit 1
fi

if [[ $(which rover) == "" ]]; then
  echo "rover not installed; see: https://www.apollographql.com/docs/rover/getting-started/"
  exit 1
fi

# if an account id is not provided, fetch it from Studio
if [[ $ACCOUNT_ID == "" ]]; then
  ACCOUNT_ARGS=(
    --silent
    --header "x-api-key: $APOLLO_KEY"
    --header 'content-type: application/json'
    --header 'apollographql-client-name: reference-architecture'
    --url 'https://graphql.api.apollographql.com/api/graphql'
    --data '{"query":"{ me { ... on User { memberships { permission account { id } } } } }"}'
  )

  if [[ $HEADER != "" ]]; then
    ACCOUNT_ARGS+=(--header "$HEADER")
  fi

  ACCOUNT_RESP=$(curl "${ACCOUNT_ARGS[@]}")
  ACCOUNT_COUNT=$(echo $ACCOUNT_RESP | jq -r ".data.me.memberships | length")

  # if more than one account exists, exit early
  if [[ $ACCOUNT_COUNT > 1 ]]; then
    echo "Apollo Studio returned more than one account."
    echo "Specify an account ID with ACCOUNT_ID=myaccount $0"
    echo "Accounts: "
    echo $(echo $ACCOUNT_RESP | jq -r ".data.me.memberships[].account.id")
    exit 1
  fi

  ACCOUNT_ID=$(echo $ACCOUNT_RESP | jq -r ".data.me.memberships[0].account.id")
fi

echo "Creating graph $GRAPH_ID on account $ACCOUNT_ID..."

CREATE_ARGS=(
  --silent
  --header "x-api-key: $APOLLO_KEY"
  --header 'content-type: application/json'
  --header 'apollographql-client-name: reference-architecture'
  --url 'https://graphql.api.apollographql.com/api/graphql'
  --data "{\"query\":\"mutation CreateGraph(\$accountId: ID!, \$newServiceId: ID!, \$name: String, \$onboardingArchitecture: OnboardingArchitecture) { newService(accountId: \$accountId, id: \$newServiceId, name: \$name, onboardingArchitecture: \$onboardingArchitecture) { id apiKeys { token } } }\",\"variables\":{\"accountId\":\"$ACCOUNT_ID\",\"newServiceId\":\"$GRAPH_ID\",\"name\":\"Build a Supergraph $(date +"%Y-%m-%d")\",\"onboardingArchitecture\":\"SUPERGRAPH\"}}"
)

if [[ $HEADER != "" ]]; then
  CREATE_ARGS+=(--header "$HEADER")
fi

CREATE_RESP=$(curl "${CREATE_ARGS[@]}")

IS_SUCCESS=$(echo $CREATE_RESP | jq -r ".data.newService")
if [[ "$IS_SUCCESS" == "null" ]]; then
  echo "Error creating graph"
  echo $CREATE_RESP | jq .
  exit 1
fi

GRAPH_KEY=$(echo $CREATE_RESP | jq -r ".data.newService.apiKeys[0].token")

# Create Operator API key for the operator to use
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

# Note: Subgraph schema publishing is now handled by the Apollo GraphOS Operator
# when Subgraph CRDs are deployed. No manual rover publish commands needed.
# We create variants by publishing dummy subgraphs to them.

echo "Creating dev and prod variants by publishing dummy subgraphs..."

for variant in "${VARIANTS[@]}"; do
  echo "Creating variant: $variant"
  
  PUBLISH_ARGS=(
    --silent
    --header "x-api-key: $GRAPH_KEY"
    --header "apollographql-client-name: reference-architecture"
    --header "apollographql-client-version: 1.0"
    --header 'content-type: application/json'
    --url 'https://api.apollographql.com/api/graphql'
    --data "{\"query\":\"mutation PublishSubgraph(\$graphId: ID!, \$graphVariant: String!, \$name: String!, \$revision: String!, \$activePartialSchema: PartialSchemaInput!, \$url: String) { graph(id: \$graphId) { publishSubgraph(graphVariant: \$graphVariant, name: \$name, revision: \$revision, activePartialSchema: \$activePartialSchema, url: \$url) { subgraphsCreated errors { message locations { column line } code } wasCreated wasUpdated } } }\",\"variables\":{\"graphId\":\"$GRAPH_ID\",\"graphVariant\":\"$variant\",\"name\":\"temp-subgraph\",\"revision\":\"1\",\"activePartialSchema\":{\"sdl\":\"type Query { temp: String }\"},\"url\":\"http://localhost:1234\"}}"
  )
  
  PUBLISH_RESP=$(curl "${PUBLISH_ARGS[@]}")
  
  if [[ $(echo $PUBLISH_RESP | jq -r ".data.graph.publishSubgraph.errors | length") > 0 ]]; then
    echo "Error creating variant $variant"
    echo $PUBLISH_RESP | jq .
    exit 1
  fi
  
  echo "Created variant: $variant"
done

# Create persisted query lists for dev and prod
# dev
CREATE_PQ_ARGS_DEV=(
    --silent
    --header "x-api-key: $APOLLO_KEY"
    --header 'content-type: application/json'
    --header 'apollographql-client-name: reference-architecture'
    --header 'apollographql-client-version: 1.0'
    --url 'https://api.apollographql.com/api/graphql'
    --data "{\"query\":\"mutation CreatePersistedQueryList(\$name: String!, \$graphId: ID!) { graph(id: \$graphId) { createPersistedQueryList(name: \$name) { ... on CreatePersistedQueryListResult { persistedQueryList { id } } } } }\",\"variables\":{\"name\":\"dev\",\"graphId\":\"$GRAPH_ID\"}}"
)

if [[ $HEADER != "" ]]; then
  CREATE_PQ_ARGS_DEV+=(--header "$HEADER")
fi

CREATE_PQ_DEV_RESP=$(curl "${CREATE_PQ_ARGS_DEV[@]}")

IS_SUCCESS=$(echo $CREATE_PQ_DEV_RESP | jq -r ".data.graph.createPersistedQueryList.persistedQueryList")
if [[ "$IS_SUCCESS" == "null" ]]; then
  echo "Error creating pq list for dev"
  echo $CREATE_PQ_DEV_RESP | jq .
  exit 1
fi

DEV_PQ_ID=$(echo $CREATE_PQ_DEV_RESP | jq -r ".data.graph.createPersistedQueryList.persistedQueryList.id")

UPDATE_DEV_PQ_LIST_ARGS=(
    --silent
    --request POST 
    --header "x-api-key: $APOLLO_KEY"
    --header 'content-type: application/json'
    --header 'apollographql-client-name: reference-architecture'
    --header 'apollographql-client-version: 1.0'
    --url 'https://api.apollographql.com/api/graphql' 
    --data "{\"query\":\"mutation LinkPersistedQueryList(\$persistedQueryListId: ID!, \$name: String!, \$graphId: ID!) { graph(id: \$graphId) { variant(name: \$name) { linkPersistedQueryList(persistedQueryListId: \$persistedQueryListId) { __typename ... on ListNotFoundError { listId message } ... on PermissionError { message } ... on VariantAlreadyLinkedError { message } } } } }\",\"variables\":{\"persistedQueryListId\":\"$DEV_PQ_ID\",\"name\":\"dev\",\"graphId\":\"$GRAPH_ID\"}}"
)

if [[ $HEADER != "" ]]; then
  UPDATE_DEV_PQ_LIST_ARGS+=(--header "$HEADER")
fi

UPDATE_DEV_PQ_LIST_RESP=$(curl "${UPDATE_DEV_PQ_LIST_ARGS[@]}")

# Check for errors in the response
ERROR_TYPE=$(echo $UPDATE_DEV_PQ_LIST_RESP | jq -r ".data.graph.variant.linkPersistedQueryList.__typename")
if [[ "$ERROR_TYPE" == "ListNotFoundError" ]] || [[ "$ERROR_TYPE" == "PermissionError" ]] || [[ "$ERROR_TYPE" == "VariantAlreadyLinkedError" ]]; then
  echo "Error linking pq list for dev"
  echo $UPDATE_DEV_PQ_LIST_RESP | jq .
  exit 1
fi

# prod
CREATE_PQ_ARGS_PROD=(
    --silent
    --header "x-api-key: $APOLLO_KEY"
    --header 'content-type: application/json'
    --header 'apollographql-client-name: reference-architecture'
    --header 'apollographql-client-version: 1.0'
    --url 'https://api.apollographql.com/api/graphql'
    --data "{\"query\":\"mutation CreatePersistedQueryList(\$name: String!, \$graphId: ID!) { graph(id: \$graphId) { createPersistedQueryList(name: \$name) { ... on CreatePersistedQueryListResult { persistedQueryList { id } } } } }\",\"variables\":{\"name\":\"prod\",\"graphId\":\"$GRAPH_ID\"}}"
)

if [[ $HEADER != "" ]]; then
  CREATE_PQ_ARGS_DEV+=(--header "$HEADER")
fi

CREATE_PQ_PROD_RESP=$(curl "${CREATE_PQ_ARGS_PROD[@]}")
IS_SUCCESS=$(echo $CREATE_PQ_PROD_RESP | jq -r ".data.graph.createPersistedQueryList.persistedQueryList")
if [[ "$IS_SUCCESS" == "null" ]]; then
  echo "Error creating pq list for prod"
  echo $CREATE_PQ_PROD_RESP | jq .
  exit 1
fi

PROD_PQ_ID=$(echo $CREATE_PQ_PROD_RESP | jq -r ".data.graph.createPersistedQueryList.persistedQueryList.id")

UPDATE_PROD_PQ_LIST_ARGS=(
    --silent
    --request POST 
    --header "x-api-key: $APOLLO_KEY"
    --header 'content-type: application/json'
    --header 'apollographql-client-name: reference-architecture'
    --header 'apollographql-client-version: 1.0'
    --url 'https://api.apollographql.com/api/graphql' 
    --data "{\"query\":\"mutation LinkPersistedQueryList(\$persistedQueryListId: ID!, \$name: String!, \$graphId: ID!) { graph(id: \$graphId) { variant(name: \$name) { linkPersistedQueryList(persistedQueryListId: \$persistedQueryListId) { __typename ... on ListNotFoundError { listId message } ... on PermissionError { message } ... on VariantAlreadyLinkedError { message } } } } }\",\"variables\":{\"persistedQueryListId\":\"$PROD_PQ_ID\",\"name\":\"prod\",\"graphId\":\"$GRAPH_ID\"}}"
)
if [[ $HEADER != "" ]]; then
  UPDATE_PROD_PQ_LIST_ARGS+=(--header "$HEADER")
fi

UPDATE_PROD_PQ_LIST_RESP=$(curl "${UPDATE_PROD_PQ_LIST_ARGS[@]}")

# Check for errors in the response
ERROR_TYPE=$(echo $UPDATE_PROD_PQ_LIST_RESP | jq -r ".data.graph.variant.linkPersistedQueryList.__typename")
if [[ "$ERROR_TYPE" == "ListNotFoundError" ]] || [[ "$ERROR_TYPE" == "PermissionError" ]] || [[ "$ERROR_TYPE" == "VariantAlreadyLinkedError" ]]; then
  echo "Error linking pq list for prod"
  echo $UPDATE_PROD_PQ_LIST_RESP | jq .
  exit 1
fi

echo ''
echo "Adding Apollo credentials as Terraform variables in .env..."
echo '' >> .env
echo "export TF_VAR_apollo_key=\"$GRAPH_KEY\"" >> .env
echo "export TF_VAR_apollo_graph_id=\"$GRAPH_ID\"" >> .env
echo "export TF_VAR_pq_dev_id=\"$DEV_PQ_ID\"" >> .env
echo "export TF_VAR_pq_prod_id=\"$PROD_PQ_ID\"" >> .env
echo "export OPERATOR_KEY=\"$OPERATOR_KEY\"" >> .env
echo "export GITHUB_ORG=\"$(git remote get-url origin 2>/dev/null | sed -E 's|.*github.com/([^/]+)/.*|\1|' || echo 'apollosolutions')\"" >> .env
echo '' >> .env
echo 'Re-run `source .env` to load them.'
