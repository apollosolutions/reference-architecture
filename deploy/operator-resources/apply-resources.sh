#!/bin/bash
set -euo pipefail

# This script applies the operator resources with the correct graph ID
# Usage: ./apply-resources.sh [environment]
# Environment defaults to "dev" if not specified

ENVIRONMENT=${1:-dev}

# Check if APOLLO_GRAPH_ID is set (load from .env if available)
if [ -f .env ]; then
    source .env
fi

if [[ -z "${APOLLO_GRAPH_ID:-}" ]]; then
    echo "Error: APOLLO_GRAPH_ID is not set. Please source .env file or set it as an environment variable."
    exit 1
fi

echo "Deploying operator resources for ${ENVIRONMENT} environment with graph ID: ${APOLLO_GRAPH_ID}"

RESOURCE_NAME="reference-architecture-${ENVIRONMENT}"

# Apply SupergraphSchema
cat <<EOF | kubectl apply -f -
apiVersion: apollographql.com/v1alpha2
kind: SupergraphSchema
metadata:
  name: ${RESOURCE_NAME}
  namespace: apollo
spec:
  graphRef: ${APOLLO_GRAPH_ID}@${ENVIRONMENT}
  selectors:
    - matchExpressions:
        - key: apollo.io/subgraph
          operator: Exists
  partial: false
EOF

# Apply Supergraph (use dev or prod file as template, or create dynamically)
if [ -f "supergraph-${ENVIRONMENT}.yaml" ]; then
    kubectl apply -f "supergraph-${ENVIRONMENT}.yaml"
else
    # Create dynamically with dev defaults
    cat <<EOF | kubectl apply -f -
apiVersion: apollographql.com/v1alpha2
kind: Supergraph
metadata:
  name: ${RESOURCE_NAME}
  namespace: apollo
spec:
  replicas: 1
  podTemplate:
    routerVersion: 2.7.0
    resources:
      requests:
        cpu: 100m
        memory: 256Mi
  schema:
    resource:
      name: ${RESOURCE_NAME}
      namespace: apollo
EOF
fi

# Apply Ingress
if [ -f "ingress-${ENVIRONMENT}.yaml" ]; then
    kubectl apply -f "ingress-${ENVIRONMENT}.yaml"
else
    # Create dynamically
    cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: router
  namespace: apollo
spec:
  ingressClassName: nginx
  rules:
    - http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: ${RESOURCE_NAME}
                port:
                  number: 80
EOF
fi

echo "Operator resources deployed successfully for ${ENVIRONMENT} environment"

