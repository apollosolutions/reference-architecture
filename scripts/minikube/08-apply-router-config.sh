#!/bin/bash
set -euo pipefail

# Script 08: Apply Router Configuration
# This script patches the router deployment to use the router-config ConfigMap
# Note: Script 07 must be run first to create the Supergraph and ConfigMap

echo "=== Step 08: Applying Router Configuration ==="

# Load environment variables from .env if it exists
if [ -f .env ]; then
    echo "Loading environment variables from .env..."
    source .env
fi

# Validate required variables
if [[ -z "${ENVIRONMENT:-}" ]]; then
    echo "Error: ENVIRONMENT is required"
    echo "Please set ENVIRONMENT in your .env file or export it:"
    echo "  export ENVIRONMENT=\"dev\""
    exit 1
fi

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo "Error: kubectl is not installed"
    exit 1
fi

# Verify cluster connection
if ! kubectl cluster-info &> /dev/null; then
    echo "Error: Cannot connect to Kubernetes cluster"
    exit 1
fi

# Resource name based on environment
RESOURCE_NAME="reference-architecture-${ENVIRONMENT}"
DEPLOYMENT_NAME="${RESOURCE_NAME}"

# Verify ConfigMap exists
if ! kubectl get configmap router-config -n apollo &>/dev/null; then
    echo "Error: router-config ConfigMap not found"
    echo "Please run 07-deploy-operator-resources.sh first to create the ConfigMap"
    exit 1
fi

# Wait for router deployment to be created
echo "Waiting for router deployment to be created..."
for i in {1..60}; do
    if kubectl get deployment ${DEPLOYMENT_NAME} -n apollo &>/dev/null; then
        echo "Router deployment found"
        break
    fi
    echo "  Waiting for deployment... ($i/60)"
    sleep 2
done

if ! kubectl get deployment ${DEPLOYMENT_NAME} -n apollo &>/dev/null; then
    echo "Error: Router deployment not found after waiting"
    echo "Please check the Supergraph status:"
    echo "  kubectl get supergraph ${RESOURCE_NAME} -n apollo"
    exit 1
fi

# Patch the router deployment to mount the ConfigMap and use it
echo "Patching router deployment to use ConfigMap..."

# Check if operator's ConfigMap volume exists and replace it with ours
# The operator creates a volume that points to a ConfigMap with name pattern reference-architecture-*-config-*
VOLUMES_JSON=$(kubectl get deployment ${DEPLOYMENT_NAME} -n apollo -o jsonpath='{.spec.template.spec.volumes}' || echo "[]")
VOLUME_INDEX=-1
INDEX=0
OPERATOR_CONFIGMAP_FOUND=false
VOLUME_NAME=""

# Check each volume to see if it points to the operator's ConfigMap
for vol_json in $(echo "$VOLUMES_JSON" | jq -c '.[]'); do
    CONFIGMAP_NAME=$(echo "$vol_json" | jq -r '.configMap.name // ""')
    if [[ -n "$CONFIGMAP_NAME" && "$CONFIGMAP_NAME" =~ ^reference-architecture.*-config- ]]; then
        VOLUME_INDEX=$INDEX
        OPERATOR_CONFIGMAP_FOUND=true
        VOLUME_NAME=$(echo "$vol_json" | jq -r '.name')
        echo "  Found operator ConfigMap volume '$VOLUME_NAME' pointing to '$CONFIGMAP_NAME'"
        break
    fi
    INDEX=$((INDEX + 1))
done

if [[ "$OPERATOR_CONFIGMAP_FOUND" == "true" ]]; then
    echo "  Replacing with our router-config ConfigMap..."
    
    if [[ $VOLUME_INDEX -ge 0 ]]; then
        # Replace the operator's ConfigMap volume with ours
        kubectl patch deployment ${DEPLOYMENT_NAME} -n apollo --type='json' -p="[
            {
                \"op\": \"replace\",
                \"path\": \"/spec/template/spec/volumes/$VOLUME_INDEX\",
                \"value\": {
                    \"name\": \"router-config\",
                    \"configMap\": {
                        \"name\": \"router-config\"
                    }
                }
            }
        ]" && echo "  Replaced operator ConfigMap volume with router-config" || {
            echo "  Warning: Failed to replace volume, trying add instead..."
            # Fallback: add our volume (will have both, but ours will be used if mounted)
            kubectl patch deployment ${DEPLOYMENT_NAME} -n apollo --type='json' -p='[
                {
                    "op": "add",
                    "path": "/spec/template/spec/volumes/-",
                    "value": {
                        "name": "router-config",
                        "configMap": {
                            "name": "router-config"
                        }
                    }
                }
            ]'
        }
    else
        # Couldn't find index, just add ours
        echo "  Could not find operator volume index, adding router-config volume..."
        kubectl patch deployment ${DEPLOYMENT_NAME} -n apollo --type='json' -p='[
            {
                "op": "add",
                "path": "/spec/template/spec/volumes/-",
                "value": {
                    "name": "router-config",
                    "configMap": {
                        "name": "router-config"
                    }
                }
            }
        ]'
    fi
else
    # No operator volume found, check if our volume exists
    if ! kubectl get deployment ${DEPLOYMENT_NAME} -n apollo -o jsonpath='{.spec.template.spec.volumes[*].name}' | grep -q "router-config"; then
        kubectl patch deployment ${DEPLOYMENT_NAME} -n apollo --type='json' -p='[
            {
                "op": "add",
                "path": "/spec/template/spec/volumes/-",
                "value": {
                    "name": "router-config",
                    "configMap": {
                        "name": "router-config"
                    }
                }
            }
        ]'
        echo "  Added router-config volume"
    else
        echo "  router-config volume already exists"
    fi
fi

# Check if volumeMount already exists, if not add it
# Also check if operator's volumeMount exists and replace it
MOUNTS_JSON=$(kubectl get deployment ${DEPLOYMENT_NAME} -n apollo -o jsonpath='{.spec.template.spec.containers[0].volumeMounts}' || echo "[]")
MOUNT_INDEX=-1
INDEX=0
OPERATOR_MOUNT_FOUND=false

# Find volumeMount that matches the operator's volume name or has wrong mount path
# Also check if there's a mount at /app (operator's default path) that needs replacing
for mount_json in $(echo "$MOUNTS_JSON" | jq -c '.[]'); do
    MOUNT_NAME=$(echo "$mount_json" | jq -r '.name')
    MOUNT_PATH=$(echo "$mount_json" | jq -r '.mountPath')
    # Check if this mount points to the operator's volume name, or if it's mounted at /app (operator's default)
    if [[ -n "$VOLUME_NAME" && "$MOUNT_NAME" == "$VOLUME_NAME" ]] || [[ "$MOUNT_PATH" == "/app" ]]; then
        MOUNT_INDEX=$INDEX
        OPERATOR_MOUNT_FOUND=true
        echo "  Found volumeMount '$MOUNT_NAME' at path '$MOUNT_PATH'"
        break
    fi
    INDEX=$((INDEX + 1))
done

if [[ "$OPERATOR_MOUNT_FOUND" == "true" ]]; then
    echo "  Replacing with router-config volumeMount at /etc/router..."
    
    if [[ $MOUNT_INDEX -ge 0 ]]; then
        # Replace the operator's volumeMount with ours
        kubectl patch deployment ${DEPLOYMENT_NAME} -n apollo --type='json' -p="[
            {
                \"op\": \"replace\",
                \"path\": \"/spec/template/spec/containers/0/volumeMounts/$MOUNT_INDEX\",
                \"value\": {
                    \"name\": \"router-config\",
                    \"mountPath\": \"/etc/router\",
                    \"readOnly\": true
                }
            }
        ]" && echo "  Replaced operator volumeMount with router-config" || {
            echo "  Warning: Failed to replace volumeMount, trying add instead..."
            kubectl patch deployment ${DEPLOYMENT_NAME} -n apollo --type='json' -p='[
                {
                    "op": "add",
                    "path": "/spec/template/spec/containers/0/volumeMounts/-",
                    "value": {
                        "name": "router-config",
                        "mountPath": "/etc/router",
                        "readOnly": true
                    }
                }
            ]'
        }
    else
        # Couldn't find index, just add ours
        echo "  Could not find operator mount index, adding router-config volumeMount..."
        kubectl patch deployment ${DEPLOYMENT_NAME} -n apollo --type='json' -p='[
            {
                "op": "add",
                "path": "/spec/template/spec/containers/0/volumeMounts/-",
                "value": {
                    "name": "router-config",
                    "mountPath": "/etc/router",
                    "readOnly": true
                }
            }
        ]'
    fi
else
    # No operator mount found, check if our mount exists
    if ! kubectl get deployment ${DEPLOYMENT_NAME} -n apollo -o jsonpath='{.spec.template.spec.containers[0].volumeMounts[*].name}' | grep -q "router-config"; then
        kubectl patch deployment ${DEPLOYMENT_NAME} -n apollo --type='json' -p='[
            {
                "op": "add",
                "path": "/spec/template/spec/containers/0/volumeMounts/-",
                "value": {
                    "name": "router-config",
                    "mountPath": "/etc/router",
                    "readOnly": true
                }
            }
        ]'
        echo "  Added router-config volumeMount"
    else
        echo "  router-config volumeMount already exists"
    fi
fi

# Check if --config args exist and replace them if needed
CURRENT_ARGS=$(kubectl get deployment ${DEPLOYMENT_NAME} -n apollo -o jsonpath='{.spec.template.spec.containers[0].args[*]}' || echo "")
if [[ "$CURRENT_ARGS" =~ "--config" ]]; then
    # The operator already set --config, we need to replace it
    # Get the full args array as JSON
    ARGS_JSON=$(kubectl get deployment ${DEPLOYMENT_NAME} -n apollo -o jsonpath='{.spec.template.spec.containers[0].args}' || echo "[]")
    
    # Find the index of --config using a simple approach
    # Convert JSON array to space-separated and find index
    ARGS_LIST=$(echo "$ARGS_JSON" | grep -o '"[^"]*"' | tr -d '"' | tr '\n' ' ')
    CONFIG_INDEX=-1
    INDEX=0
    for arg in $ARGS_LIST; do
        if [[ "$arg" == "--config" ]]; then
            CONFIG_INDEX=$INDEX
            break
        fi
        INDEX=$((INDEX + 1))
    done
    
    if [[ $CONFIG_INDEX -ge 0 ]]; then
        # Replace the --config argument and the following path argument
        NEXT_INDEX=$((CONFIG_INDEX + 1))
        echo "  Replacing existing --config argument at index $CONFIG_INDEX..."
        kubectl patch deployment ${DEPLOYMENT_NAME} -n apollo --type='json' -p="[
            {
                \"op\": \"replace\",
                \"path\": \"/spec/template/spec/containers/0/args/$CONFIG_INDEX\",
                \"value\": \"--config\"
            },
            {
                \"op\": \"replace\",
                \"path\": \"/spec/template/spec/containers/0/args/$NEXT_INDEX\",
                \"value\": \"/etc/router/router.yaml\"
            }
        ]" && echo "  Successfully replaced --config arguments" || {
            echo "  Warning: Replace failed, trying remove-then-add approach..."
            # Fallback: remove old args, then add new ones
            # Remove in reverse order to avoid index shifting
            kubectl patch deployment ${DEPLOYMENT_NAME} -n apollo --type='json' -p="[
                {
                    \"op\": \"remove\",
                    \"path\": \"/spec/template/spec/containers/0/args/$NEXT_INDEX\"
                },
                {
                    \"op\": \"remove\",
                    \"path\": \"/spec/template/spec/containers/0/args/$CONFIG_INDEX\"
                }
            ]" 2>/dev/null || true
            # Add new --config args
            kubectl patch deployment ${DEPLOYMENT_NAME} -n apollo --type='json' -p='[
                {
                    "op": "add",
                    "path": "/spec/template/spec/containers/0/args/-",
                    "value": "--config"
                },
                {
                    "op": "add",
                    "path": "/spec/template/spec/containers/0/args/-",
                    "value": "/etc/router/router.yaml"
                }
            ]'
            echo "  Added new --config arguments"
        }
    else
        echo "  Warning: Could not find --config index, adding new --config arguments..."
        kubectl patch deployment ${DEPLOYMENT_NAME} -n apollo --type='json' -p='[
            {
                "op": "add",
                "path": "/spec/template/spec/containers/0/args/-",
                "value": "--config"
            },
            {
                "op": "add",
                "path": "/spec/template/spec/containers/0/args/-",
                "value": "/etc/router/router.yaml"
            }
        ]'
    fi
else
    # No --config exists, add it
    echo "  Adding --config arguments..."
    kubectl patch deployment ${DEPLOYMENT_NAME} -n apollo --type='json' -p='[
        {
            "op": "add",
            "path": "/spec/template/spec/containers/0/args/-",
            "value": "--config"
        },
        {
            "op": "add",
            "path": "/spec/template/spec/containers/0/args/-",
            "value": "/etc/router/router.yaml"
        }
    ]'
    echo "  Added --config arguments"
fi

echo "Router deployment patched"

# Wait for rollout to complete
echo "Waiting for router rollout to complete..."
kubectl rollout status deployment/${DEPLOYMENT_NAME} -n apollo --timeout=300s || true

# Wait for router to be ready
echo "Waiting for router to be ready..."
kubectl wait --for=condition=ready --timeout=300s supergraph/${RESOURCE_NAME} -n apollo || true

echo ""
echo "✓ Router configuration applied!"
echo ""
echo "Router configuration has been applied via ConfigMap:"
echo "  ConfigMap: router-config (contains router.yaml)"
echo "  Mounted at: /etc/router/router.yaml"
echo "  Router args: --config /etc/router/router.yaml"
echo ""
echo "Monitor router status with:"
echo "  kubectl get supergraphs -n apollo"
echo "  kubectl get pods -n apollo"
echo "  kubectl logs -n apollo deployment/${DEPLOYMENT_NAME}"
echo ""
echo "Next step: Run 09-deploy-ingress.sh to setup external access"

