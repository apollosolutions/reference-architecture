#!/bin/bash
set -euo pipefail

# Script 01: Setup Minikube Cluster
# This script installs and starts a Minikube cluster

echo "=== Step 01: Setting up Minikube Cluster ==="

# Check if minikube is installed
if ! command -v minikube &> /dev/null; then
    echo "Error: minikube is not installed"
    echo "Please install minikube: https://minikube.sigs.k8s.io/docs/start/"
    exit 1
fi

# Check if kubectl is installed
if ! command -v kubectl &> /dev/null; then
    echo "Error: kubectl is not installed"
    echo "Please install kubectl: https://kubernetes.io/docs/tasks/tools/"
    exit 1
fi

# Check if minikube cluster already exists
if minikube status &> /dev/null; then
    echo "Minikube cluster already exists. Starting it..."
    minikube start
else
    echo "Creating new Minikube cluster..."
    minikube start
fi

# Enable ingress addon for external access
echo "Enabling ingress addon..."
minikube addons enable ingress

# Verify cluster is running
echo "Verifying cluster status..."
minikube status

# Configure kubectl to use minikube context
echo "Configuring kubectl context..."
kubectl config use-context minikube

echo ""
echo "✓ Minikube cluster is ready!"
echo ""
echo "Next step: Run 02-setup-apollo-graph.sh to create your Apollo GraphOS graph"

