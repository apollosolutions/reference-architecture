# Setup

⏱ Estimated time: 30 minutes

This guide will walk you through setting up the Apollo Federation Supergraph reference architecture on Minikube for local development.

- [Setup](#setup)
  - [Prerequisites](#prerequisites)
  - [Step 1: Install Minikube and Dependencies](#step-1-install-minikube-and-dependencies)
  - [Step 2: Configure Environment Variables](#step-2-configure-environment-variables)
  - [Step 3: Run Setup Scripts](#step-3-run-setup-scripts)
  - [Step 4: Access Your Supergraph](#step-4-access-your-supergraph)
  - [Creating Additional Environments](#creating-additional-environments)

## Prerequisites

Before you begin, ensure you have:

- [Minikube](https://minikube.sigs.k8s.io/docs/start/) installed and configured
- [kubectl](https://kubernetes.io/docs/tasks/tools/) installed
- [Helm](https://helm.sh/docs/intro/install/) installed
- [Docker](https://docs.docker.com/get-docker/) installed
- [jq](https://stedolan.github.io/jq/download/) installed
- [curl](https://curl.se/) installed
- An [Apollo GraphOS account](https://studio.apollographql.com/signup) with a Personal API key

### Get Your Apollo GraphOS Personal API Key

1. Go to [Apollo GraphOS Studio](https://studio.apollographql.com)
2. Navigate to [User Settings > API Keys](https://studio.apollographql.com/user-settings/api-keys)
3. Create a new Personal API key or use an existing one
4. Copy the API key value

## Step 1: Install Minikube and Dependencies

### Install Minikube

Follow the [Minikube installation guide](https://minikube.sigs.k8s.io/docs/start/) for your operating system.

### Verify Installation

```bash
minikube version
kubectl version --client
helm version
docker --version
```

## Step 2: Configure Environment Variables

1. Copy the environment template:

```bash
cp scripts/minikube/.env.sample .env
```

2. Edit `.env` and set your Apollo GraphOS Personal API key and environment:

```bash
export APOLLO_KEY="your-apollo-personal-api-key"
export ENVIRONMENT="dev"  # Required: e.g., "dev", "prod", "staging"
```

The `ENVIRONMENT` variable is required and allows you to create multiple environments. Each environment will have its own Apollo GraphOS variant.

**Note:** When deploying subgraphs, the scripts will look for environment-specific values files at `subgraphs/{subgraph}/deploy/environments/${ENVIRONMENT}.yaml`. If this file exists, it will be used to override the default `values.yaml`. If it doesn't exist, the default `values.yaml` will be used. The repository includes `dev.yaml` and `prod.yaml` files for all subgraphs. If you create a custom environment name, you can optionally create matching values files for environment-specific configurations.

## Step 3: Run Setup Scripts

Run the scripts in order from the repository root:

### Script 01: Setup Minikube Cluster

```bash
./scripts/minikube/01-setup-minikube.sh
```

This script:
- Starts or creates a Minikube cluster
- Enables the ingress addon for external access
- Configures kubectl to use the Minikube context

### Script 02: Setup Apollo GraphOS Graph

```bash
./scripts/minikube/02-setup-apollo-graph.sh
```

This script:
- Creates an Apollo GraphOS graph
- Creates an Operator API key
- Creates a variant for your environment
- Saves configuration to `.env`

**Note:** Make sure your `.env` file has `APOLLO_KEY` set before running this script.

### Script 03: Setup Kubernetes Cluster

```bash
source .env  # Load the variables set by script 02
./scripts/minikube/03-setup-cluster.sh
```

This script:
- Creates required namespaces (`apollo-operator`, `apollo`)
- Creates the operator API key secret
- Installs the Apollo GraphOS Operator via Helm

### Script 04: Build Docker Images

```bash
./scripts/minikube/04-build-images.sh
```

This script:
- Configures Docker to use Minikube's Docker daemon
- Builds all subgraph images locally
- Tags images as `{subgraph}:local`
- Builds coprocessor and client images (for future use)

### Script 05: Deploy Subgraphs

```bash
./scripts/minikube/05-deploy-subgraphs.sh
```

This script:
- Deploys each subgraph using Helm charts
- Creates Subgraph CRDs with inline SDL schemas
- Configures images to use local builds

Monitor subgraph deployment:

```bash
kubectl get subgraphs --all-namespaces
kubectl get pods --all-namespaces
```

### Script 06: Deploy Operator Resources

```bash
./scripts/minikube/06-deploy-operator-resources.sh
```

This script:
- Deploys SupergraphSchema CRD (triggers composition)
- Deploys Supergraph CRD (deploys the Apollo Router)
- Waits for the router to be ready

Monitor router deployment:

```bash
kubectl get supergraphs -n apollo
kubectl get pods -n apollo
kubectl describe supergraph reference-architecture-${ENVIRONMENT} -n apollo
```

### Script 07: Deploy Ingress

```bash
./scripts/minikube/07-deploy-ingress.sh
```

This script:
- Deploys an Ingress resource for external access
- Provides access URLs for the router

### Script 08: Deploy Client (Optional)

```bash
./scripts/minikube/08-deploy-client.sh
```

This script:
- Builds and deploys the client application
- Sets up ingress for client access

## Step 4: Access Your Supergraph

After running all scripts, you can access your supergraph in several ways:

### Option 1: Using Ingress IP

If ingress is configured, get the IP:

```bash
kubectl get ingress router -n apollo
```

Then access at `http://<INGRESS_IP>`

### Option 2: Using Minikube Service

```bash
minikube service reference-architecture-${ENVIRONMENT} -n apollo
```

This will open the router in your default browser.

### Option 3: Using Port Forwarding

```bash
kubectl port-forward service/reference-architecture-${ENVIRONMENT} -n apollo 4000:80
```

Then access at `http://localhost:4000`

### Verify Router is Working

Test the router health endpoint:

```bash
curl http://localhost:4000/.well-known/apollo/server-health
```

Or visit the router in Apollo Studio:
1. Go to [Apollo GraphOS Studio](https://studio.apollographql.com)
2. Select your graph
3. Navigate to the variant (e.g., "dev")
4. View the router status and metrics

## Creating Additional Environments

To create a new environment (e.g., "prod"):

1. Set the environment variable:

```bash
export ENVIRONMENT="prod"
```

2. Run scripts 02-07 again with the new environment:

```bash
./scripts/minikube/02-setup-apollo-graph.sh  # Creates prod variant
source .env
./scripts/minikube/03-setup-cluster.sh       # Uses same cluster
./scripts/minikube/04-build-images.sh       # Reuses images
./scripts/minikube/05-deploy-subgraphs.sh   # Deploys to prod namespaces
./scripts/minikube/06-deploy-operator-resources.sh  # Creates prod router
./scripts/minikube/07-deploy-ingress.sh     # Updates ingress
```

Each environment will have:
- Its own Apollo GraphOS variant
- Separate Kubernetes resources (namespaces, services, etc.)
- Its own router instance

## Troubleshooting

### Minikube won't start

```bash
minikube delete
minikube start
```

### Images not found

Ensure script 04 built the images and Docker is using Minikube's daemon:

```bash
eval $(minikube docker-env)
docker images | grep local
```

### Subgraphs not publishing schemas

Check subgraph status:

```bash
kubectl describe subgraph <subgraph-name> -n <subgraph-namespace>
```

Look for errors in schema extraction or API key authentication.

### Router not deploying

Check router status:

```bash
kubectl describe supergraph reference-architecture-${ENVIRONMENT} -n apollo
kubectl logs -n apollo deployment/reference-architecture-${ENVIRONMENT}
```

### Ingress not working

Ensure ingress addon is enabled:

```bash
minikube addons enable ingress
kubectl get pods -n ingress-nginx
```

## Next Steps

- Read the [Operator Guide](./operator-guide.md) to understand how the Apollo GraphOS Operator works
- Explore your supergraph in [Apollo Studio](https://studio.apollographql.com)
- Make schema changes and see them automatically composed and deployed
