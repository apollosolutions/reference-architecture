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

for variant in "${VARIANTS[@]}"; do
  for folder in ../../subgraphs/*; do
    if [[ $folder == *"node_modules"* ]]; then
      continue
    fi
    rover subgraph publish $GRAPH_ID@$variant --name $(basename $folder) --routing-url http://graphql.$(basename $folder).svc.cluster.local:4001 --schema $folder/schema.graphql --client-timeout 120
  done
done

# dev
CREATE_PQ_ARGS_DEV=(
    --silent
    --header "x-api-key: $APOLLO_KEY"
    --header 'content-type: application/json'
    --url 'https://graphql.api.apollographql.com/api/graphql'
    --data "{\"query\":\"mutation CreatePersistedQueryList(\$name: String!, \$graphId: ID!, \$linkedVariants: [String!]) {\n  graph(id: \$graphId) {\n    createPersistedQueryList(name: \$name, linkedVariants: \$linkedVariants) {\n      ... on CreatePersistedQueryListResult {\n        persistedQueryList {\n          id\n        }\n      }\n    }\n  }\n}\",\"variables\":{\"name\":\"dev\",\"graphId\":\"$GRAPH_ID\",\"linkedVariants\":[\"$GRAPH_ID@dev\"]}}"
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
    --url 'https://graphql.api.apollographql.com/api/graphql' 
    --data "{\"query\":\"mutation LinkPersistedQueryList(\$persistedQueryListId: ID!, \$name: String!, \$graphId: ID!) {\\n  graph(id: \$graphId) {\\n    variant(name: \$name) {\\n      linkPersistedQueryList(persistedQueryListId: \$persistedQueryListId) {\\n    __typename    ... on LinkPersistedQueryListResult {\\n          persistedQueryList {\\n            id\\n          }\\n        }\\n      }\\n    }\\n  }\\n}\",\"variables\":{\"persistedQueryListId\":\"$DEV_PQ_ID\",\"name\":\"dev\",\"graphId\":\"$GRAPH_ID\"}}"
)

if [[ $HEADER != "" ]]; then
  UPDATE_DEV_PQ_LIST_ARGS+=(--header "$HEADER")
fi

UPDATE_DEV_PQ_LIST_RESP=$(curl "${UPDATE_DEV_PQ_LIST_ARGS[@]}")

IS_SUCCESS=$(echo $UPDATE_DEV_PQ_LIST_RESP | jq -r ".data.graph.variant.linkPersistedQueryList.persistedQueryList")
if [[ "$IS_SUCCESS" == "null" ]]; then
  echo "Error updating pq list for dev"
  echo ${UPDATE_DEV_PQ_LIST_ARGS[@]}
  echo $UPDATE_DEV_PQ_LIST_RESP | jq .
  exit 1
fi

# prod
CREATE_PQ_ARGS_PROD=(
    --silent
    --header "x-api-key: $APOLLO_KEY"
    --header 'content-type: application/json'
    --url 'https://graphql.api.apollographql.com/api/graphql'
    --data "{\"query\":\"mutation CreatePersistedQueryList(\$name: String!, \$graphId: ID!, \$linkedVariants: [String!]) {\n  graph(id: \$graphId) {\n    createPersistedQueryList(name: \$name, linkedVariants: \$linkedVariants) {\n      ... on CreatePersistedQueryListResult {\n        persistedQueryList {\n          id\n        }\n      }\n    }\n  }\n}\",\"variables\":{\"name\":\"prod\",\"graphId\":\"$GRAPH_ID\",\"linkedVariants\":[\"prod\"]}}"
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
    --url 'https://graphql.api.apollographql.com/api/graphql' 
    --data "{\"query\":\"mutation LinkPersistedQueryList(\$persistedQueryListId: ID!, \$name: String!, \$graphId: ID!) {\\n  graph(id: \$graphId) {\\n    variant(name: \$name) {\\n      linkPersistedQueryList(persistedQueryListId: \$persistedQueryListId) {\\n        ... on LinkPersistedQueryListResult {\\n          persistedQueryList {\\n            id\\n          }\\n        }\\n      }\\n    }\\n  }\\n}\",\"variables\":{\"persistedQueryListId\":\"$PROD_PQ_ID\",\"name\":\"prod\",\"graphId\":\"$GRAPH_ID\"}}"
)
if [[ $HEADER != "" ]]; then
  UPDATE_PROD_PQ_LIST_ARGS+=(--header "$HEADER")
fi

UPDATE_PROD_PQ_LIST_RESP=$(curl "${UPDATE_PROD_PQ_LIST_ARGS[@]}")

IS_SUCCESS=$(echo $UPDATE_PROD_PQ_LIST_RESP | jq -r ".data.graph.variant.linkPersistedQueryList.persistedQueryList")
if [[ "$IS_SUCCESS" == "null" ]]; then
  echo "Error updating pq list for prod"
  echo $CREATE_PQ_PROD_RESP | jq .
  exit 1
fi

echo ''
echo "Adding Apollo credentials as Terraform variables in .env..."
echo '' >> .env
echo "export TF_VAR_apollo_key=\"$GRAPH_KEY\"" >> .env
echo "export TF_VAR_apollo_graph_id=\"$GRAPH_ID\"" >> .env
echo "export TF_VAR_pq_dev_id=\"$DEV_PQ_ID\"" >> .env
echo "export TF_VAR_pq_prod_id=\"$PROD_PQ_ID\"" >> .env
echo '' >> .env
echo 'Re-run `source .env` to load them.'
