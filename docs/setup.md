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
export ENVIRONMENT="dev"
```

The `ENVIRONMENT` variable is required and allows you to create multiple environments. Each environment will reference its own Apollo GraphOS variant (e.g., `@dev`, `@prod`) in the SupergraphSchema CRD. Variants are created automatically when schemas are first published to them.

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
- Saves configuration to `.env`

**Note:** Make sure your `.env` file has `APOLLO_KEY` set before running this script.

**Note:** Variants (e.g., `@dev`, `@prod`) are referenced in the SupergraphSchema CRD and will be created automatically when schemas are first published to those variants.

### Script 03: Setup Kubernetes Cluster

```bash
source .env
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

### Script 06: Deploy Coprocessor

The coprocessor handles JWT authentication for the `@authenticated` directive and is required for the router to function properly.

```bash
./scripts/minikube/06-deploy-coprocessor.sh
```

This script:
- Builds the coprocessor Docker image (if not already built)
- Deploys the coprocessor using Helm
- Waits for coprocessor pods to be ready

**Note:** The coprocessor validates JWT tokens from the users subgraph's JWKS endpoint and enables the `@authenticated` directive to work properly. It must be deployed before the router (script 07).

### Script 07: Deploy Operator Resources

```bash
./scripts/minikube/07-deploy-operator-resources.sh
```

This script:
- Deploys SupergraphSchema CRD (triggers composition)
- Deploys Supergraph CRD with router configuration (deploys the Apollo Router)
- Waits for the router deployment to be created

**Note:** The coprocessor (script 06) must be deployed before running this script.

**Note:** The router is configured with telemetry enabled. If you plan to use distributed tracing, it's recommended to deploy the telemetry stack (script 10) before deploying the router to avoid connection errors in the router logs. However, the router will still function correctly even if the telemetry collector is not available - you'll just see connection errors in the logs until the collector is deployed.

Monitor router deployment:

```bash
kubectl get supergraphs -n apollo
kubectl get pods -n apollo
kubectl describe supergraph reference-architecture-${ENVIRONMENT} -n apollo
```

### Script 08: Setup Router Access

```bash
./scripts/minikube/08-setup-router-access.sh
```

This script:
- Enables and configures the ingress controller addon (required for the client application's Ingress resource)
- Configures the ingress controller as LoadBalancer for `minikube tunnel` support
- Determines and saves the router URL to `.env` file
- **Note:** The router does not use an Ingress resource - the client's nginx proxies to it internally. The ingress controller is needed for the client's Ingress.

### Script 09: Deploy Client

```bash
./scripts/minikube/09-deploy-client.sh
```

This script:
- Builds and deploys the client application
- Sets up ingress for client access

**Note:** The client is required if you want to access the router via the ingress controller (minikube tunnel or NodePort). If you only need direct router access, you can use port-forward (Option 2 in Step 4) and skip this script.

### Script 10: Deploy Telemetry Stack (Optional)

Deploy Zipkin and OpenTelemetry Collector for distributed tracing:

```bash
./scripts/minikube/10-deploy-telemetry.sh
```

This script:
- Creates the `monitoring` namespace
- Deploys Zipkin for trace visualization
- Deploys OpenTelemetry Collector to receive traces from router and subgraphs
- Waits for both services to be ready

**Note:** This script is optional. Telemetry is configured for all environments (dev and prod) but the telemetry stack only needs to be deployed once per cluster. The collector receives traces from all subgraphs and the router, then exports them to Zipkin.

**Recommended:** Deploy telemetry (script 10) before deploying the router (script 07) to avoid connection errors in router logs. If you've already deployed the router, you can deploy telemetry at any time - the router will automatically start sending traces once the collector is available.

**Access Zipkin UI:**

```bash
kubectl port-forward -n monitoring svc/zipkin 9411:9411
```

Then open http://localhost:9411 in your browser to view traces.

## Step 4: Access Your Supergraph

After running all scripts, you can access your supergraph in several ways:

### Option 1: Using Minikube Tunnel (requires Script 09)

**Note:** This option requires the client application to be deployed (Script 09) because it uses the client's Ingress resource.

The ingress controller has been configured as a LoadBalancer service. To access it via `minikube tunnel`:

```bash
minikube tunnel
```

**Troubleshooting if tunnel hangs:**
- Check if tunnel is already running: `ps aux | grep 'minikube tunnel'`
- Stop existing tunnel: `pkill -f 'minikube tunnel'`
- Try running with explicit cleanup: `minikube tunnel --cleanup`
- On macOS, if sudo password isn't prompted, try: `sudo minikube tunnel`

**Important notes:**
- You may see a message "Starting tunnel for service router" - **this can be safely ignored**
- The "router" is an Ingress resource (not a service), so it doesn't need tunneling
- Only the `ingress-nginx-controller` LoadBalancer service needs tunneling
- Wait for the "Status: running" message
- Access the client UI at: `http://127.0.0.1/`

**Why you see "router" in the tunnel output:**
The ingress controller automatically sets a LoadBalancer status on Ingress resources, which makes `minikube tunnel` think it needs to tunnel them. However, since the ingress controller is already being tunneled, the router is accessible through it. You can safely ignore this message.

### Option 2: Using Port Forwarding (no client required)

Port forward directly to the router service. This method does not require the client application:

```bash
kubectl port-forward service/reference-architecture-${ENVIRONMENT} -n apollo 4000:80
```

Then access at `http://localhost:4000` in your browser.

**Note:** Keep the port-forward command running in a terminal while you access the router.

### Option 3: Using Ingress via NodePort (requires Script 09)

**Note:** This option requires the client application to be deployed (Script 09) because it uses the client's Ingress resource.

Get the Minikube IP and ingress controller NodePort:

```bash
MINIKUBE_IP=$(minikube ip)
NODEPORT=$(kubectl get svc ingress-nginx-controller -n ingress-nginx -o jsonpath='{.spec.ports[?(@.name=="http")].nodePort}')
echo "Access at: http://${MINIKUBE_IP}:${NODEPORT}"
```

**Note:** This method may not work reliably on macOS due to network routing. Use Option 1 (minikube tunnel) instead.

### Verify Router is Working

Test the router with a simple GraphQL query:

```bash
curl -X POST http://localhost:4000 \
  -H "Content-Type: application/json" \
  -d '{"query":"{ __typename }"}'
```

Or test the health endpoint (if accessible on the main port):

```bash
curl http://localhost:4000/health
```

## Step 5: Logging Into the Client Application

If you deployed the client application (script 09), you can log in using the following test credentials:

### Test Users

The application includes three test users:

| Username | Password | Email | Notes |
|----------|----------|-------|-------|
| `user1` | Any non-empty password | user1@contoso.org | Has 2 credit cards, cart with items |
| `user2` | Any non-empty password | user2@contoso.org | Has 1 debit card, cart with items |
| `user3` | Any non-empty password | user3@contoso.org | Has debit card and bank account, empty cart |

### Login Instructions

1. Navigate to the client application (typically at `http://127.0.0.1/` if using minikube tunnel)
2. Click "Login" in the navigation menu
3. Enter one of the test usernames (e.g., `user1`)
4. Enter any non-empty password (e.g., `password`)
5. Optionally enter scopes (comma-separated, e.g., `user:read:email`)
6. Click "Sign In"

**Note:** The password validation only checks that it's not empty. Any non-empty password will work for authentication.

### Scopes

Scopes are optional but can be used to control access to certain fields:
- `user:read:email` - Allows reading the user's email address

## Creating Additional Environments

To create a new environment (e.g., "prod"):

1. Set the environment variable:

```bash
export ENVIRONMENT="prod"
```

2. Run scripts 02-09 again with the new environment:

```bash
./scripts/minikube/02-setup-apollo-graph.sh
source .env
./scripts/minikube/03-setup-cluster.sh
./scripts/minikube/04-build-images.sh
./scripts/minikube/05-deploy-subgraphs.sh
./scripts/minikube/06-deploy-coprocessor.sh
./scripts/minikube/07-deploy-operator-resources.sh
./scripts/minikube/08-setup-router-access.sh
./scripts/minikube/09-deploy-client.sh
```

**Note:** Script 10 (telemetry) only needs to be run once per cluster, not per environment. All environments share the same telemetry stack.

Each environment will have:
- Its own Apollo GraphOS variant (created automatically when schemas are published)
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

### Router configuration not applied

If the router is not picking up configuration changes:

1. **Verify routerConfig in Supergraph CRD:**
   ```bash
   kubectl get supergraph reference-architecture-${ENVIRONMENT} -n apollo -o yaml | grep -A 50 routerConfig
   ```

2. **Check router deployment status:**
   ```bash
   kubectl describe deployment reference-architecture-${ENVIRONMENT} -n apollo
   kubectl get pods -n apollo
   ```

3. **Check router logs for configuration errors:**
   ```bash
   kubectl logs -n apollo deployment/reference-architecture-${ENVIRONMENT} | grep -i "config\|error"
   ```

4. **Re-apply router configuration:**
   ```bash
   kubectl apply -f deploy/operator-resources/supergraph-${ENVIRONMENT}.yaml
   ```

For more details on updating router configuration, see the [Operator Guide](./operator-guide.md#updating-router-configuration).

### Router pods in CrashLoopBackOff

If router pods are crashing:

1. **Check pod logs:**
   ```bash
   kubectl logs -n apollo deployment/reference-architecture-${ENVIRONMENT} --previous
   ```

2. **Common causes:**
   - Invalid YAML in `spec.routerConfig` (check syntax in Supergraph CRD)
   - Schema composition issues (check SupergraphSchema status)
   - Missing coprocessor (verify coprocessor is running)

3. **Verify configuration syntax:**
   ```bash
   # Check if Supergraph CRD has valid routerConfig
   kubectl get supergraph reference-architecture-${ENVIRONMENT} -n apollo -o yaml | grep -A 50 routerConfig
   ```

### Ingress not working

Ensure ingress addon is enabled:

```bash
minikube addons enable ingress
kubectl get pods -n ingress-nginx
```

### Minikube tunnel hangs or doesn't prompt for password

If `minikube tunnel` hangs without prompting for your sudo password:

1. **Check if tunnel is already running:**
   ```bash
   ps aux | grep 'minikube tunnel'
   ```

2. **Stop any existing tunnel processes:**
   ```bash
   pkill -f 'minikube tunnel'
   ```

3. **Try running with cleanup flag:**
   ```bash
   minikube tunnel --cleanup
   ```

4. **On macOS, try running with sudo:**
   ```bash
   sudo minikube tunnel
   ```

5. **Alternative: Use NodePort or port-forward instead:**
   - NodePort: Access via `http://$(minikube ip):$(kubectl get svc ingress-nginx-controller -n ingress-nginx -o jsonpath='{.spec.ports[?(@.name=="http")].nodePort}')`
   - Port-forward: `kubectl port-forward service/reference-architecture-${ENVIRONMENT} -n apollo 4000:80`

## Next Steps

- Read the [Operator Guide](./operator-guide.md) to understand how the Apollo GraphOS Operator works
- Explore your supergraph in [Apollo Studio](https://studio.apollographql.com)
- Make schema changes and see them automatically composed and deployed
