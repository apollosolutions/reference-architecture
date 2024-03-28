# Setup

⏱ Estimated time: 45 minutes

- [Setup](#setup)
  - [Part A: Gather accounts and credentials](#part-a-gather-accounts-and-credentials)
    - [Clone this repo](#clone-this-repo)
    - [Install dependencies](#install-dependencies)
      - [Minimum required dependencies](#minimum-required-dependencies)
      - [GCP](#gcp)
      - [AWS](#aws)
    - [Gather accounts](#gather-accounts)
    - [Gather credentials](#gather-credentials)
      - [ GCP](#-gcp)
      - [ AWS](#-aws)
    - [Export all necessary variables](#export-all-necessary-variables)
    - [Run setup commands](#run-setup-commands)
      - [ GCP](#-gcp-1)
      - [ AWS](#-aws-1)
      - [General](#general)
  - [Part B: Provision resources](#part-b-provision-resources)
    - [Create Kubernetes clusters, basic infrastructure, and Github repositories](#create-kubernetes-clusters-basic-infrastructure-and-github-repositories)
    - [Run cluster setup script](#run-cluster-setup-script)
  - [Part C: Deploy applications](#part-c-deploy-applications)
    - [Deploy subgraphs to dev](#deploy-subgraphs-to-dev)
    - [Deploy subgraphs to prod](#deploy-subgraphs-to-prod)
    - [Deploy the coprocessor and router](#deploy-the-coprocessor-and-router)
      - [ GCP](#-gcp-2)
      - [ AWS](#-aws-2)
    - [Deploy the client](#deploy-the-client)
      - [ GCP](#-gcp-3)
      - [ AWS](#-aws-3)
      - [ GCP](#-gcp-4)
      - [ AWS](#-aws-4)

## Part A: Gather accounts and credentials

### Clone this repo

```
git clone https://github.com/apollosolutions/reference-architecture.git
cd reference-architecture
git pull
```

### Install dependencies

#### Minimum required dependencies

- [Terraform](https://learn.hashicorp.com/tutorials/terraform/install-cli)
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- [kubectx](https://github.com/ahmetb/kubectx#installation)
- [Github CLI](https://cli.github.com/)
- [jq](https://stedolan.github.io/jq/download/)

#### GCP

- [GCloud CLI](https://cloud.google.com/sdk/docs/install)
- Optional: [Helm](https://helm.sh/docs/intro/install/)

#### AWS

- [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
- [eksctl](https://eksctl.io/introduction/#installation)
- Optional: [Helm](https://helm.sh/docs/intro/install/)


<!-- #### Minikube

- [Minikube](https://minikube.sigs.k8s.io/docs/start/) configured according to the link
- [Helm](https://helm.sh/docs/intro/install/) -->

### Gather accounts

- [Github](https://github.com/signup)
- [Apollo GraphOS](https://studio.apollographql.com/signup?referrer=reference-architecture)
- If using a cloud provider: 
  - [Google Cloud](https://console.cloud.google.com/freetrial)
    - Must have a project [with billing enabled](https://cloud.google.com/resource-manager/docs/creating-managing-projects#gcloud)
  - [AWS](https://signin.aws.amazon.com/signin) with billing enabled

### Gather credentials

#### <image src="../images/gcp.svg" height="13" style="margin:auto;" /> GCP

- Google Cloud project ID
- [Github personal access token](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/creating-a-personal-access-token)
  - [Settings > Developer Settings > Personal Access Tokens](https://github.com/settings/tokens)
  - Grant it permissions to the following scopes:
    - `repo` (for creating repos)
    - `delete_repo` (for cleanup at the end)
- [Apollo GraphOS Personal API key](https://studio.apollographql.com/user-settings/api-keys)

#### <image src="../images/aws.svg" height="13" style="margin:auto;" /> AWS

- [AWS Access Key and Secret for use with the AWS CLI*](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-files.html)
  - Additionally, ensure you either:
    - Set the default region during the AWS CLI configuration
    - Set the `AWS_REGION` environment variable when running commands
- [Github personal access token](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/creating-a-personal-access-token)
  - [Settings > Developer Settings > Personal Access Tokens](https://github.com/settings/tokens)
  - Grant it permissions to the following scopes:
    - `repo` (for creating repos)
    - `delete_repo` (for cleanup at the end)
- [Apollo GraphOS Personal API key](https://studio.apollographql.com/user-settings/api-keys)

\* Please note to use an account with Administrator privileges, or at minimum, the ability to run: 

* Terraform, which creates: 
  * IAM user and policy
  * EKS cluster and node groups, and associates IAM permissions to Kubernetes service accounts
  * VPC and subnets

### Export all necessary variables

First, change directories in the cloud provider you wish to use. All Terraform is within the `terraform` root level folder, with each provider having a subfolder within. For the below examples, we'll assume GCP, however the others will use the same commands. 

Next, make a copy of `.env.sample` called `.env` to keep track of these values. You can run `source .env` to reload all environment variables in a new terminal session.

```sh
# in either terraform/aws or terraform/gcp
cp .env.sample .env
```

Edit the new `.env` file:

```sh
export PROJECT_ID="<your google cloud project id>" # if using AWS, you will not see this line and can omit this
export APOLLO_KEY="<your apollo personal api key>"
export GITHUB_ORG="<your github account name or organization name>"
export TF_VAR_github_token="<your github personal access token>"
```

Run this script to create your graph and get environment variables for GraphOS:

```sh
# in the respective terraform/ folder
source .env
./create_graph.sh
```

The script adds a few more environment variables to `.env`, so reload your environment using:

```sh
source .env
```

### Run setup commands

#### <image src="../images/gcp.svg" height="13" style="margin:auto;" /> GCP

```sh
gcloud components update
gcloud components install gke-gcloud-auth-plugin
gcloud auth login

gcloud config set project ${PROJECT_ID}
gcloud services enable \
  container.googleapis.com \
  secretmanager.googleapis.com \
  cloudasset.googleapis.com \
  storage.googleapis.com
gh auth login
```

#### <image src="../images/aws.svg" height="13" style="margin:auto;" /> AWS

```sh
aws configure
gh auth login
```


<!-- #### Minikube

```sh
gh auth login
``` -->

#### General

<details>
  <summary>Optional: how do I specify a different name for clusters and repos? (The default is "apollo-supergraph-k8s".)</summary>

Before running `create_graph.sh`, `setup_clusters.sh`, or `terraform apply` export the prefix as as environment variables:

```sh
export CLUSTER_PREFIX=my-custom-prefix
export TF_VAR_demo_name=$CLUSTER_PREFIX
```

</details>

## Part B: Provision resources

<details>
  <summary>Have you run this tutorial before?</summary>

You may need to clean up your Github packages before creating new repos of the same name. Visit `https://github.com/<your github username>?tab=packages` and delete the packages created by the previous versions of the repos.

</details>

### Create Kubernetes clusters, basic infrastructure, and Github repositories

**Note: If using a cloud provider, the following commands will create resources on your cloud provider account and begin to accrue a cost.** The reference infrastructure defaults to a lower-cost environment (small node count and instance size), however it will not be covered by either of GCP's or AWS's free tiers.

<!-- **Note: If you are using Minikube, this will not create a local cluster and instead configure the local environment to be ready to be deployed to.** -->

```sh
# for example, if using GCP
cd terraform/gcp
terraform init # takes about 2 minutes
terraform apply # will print plan then prompt for confirmation
# takes about 10-15 minutes
```

**Note**: If using GCP, you might get an `Invalid provider configuration (no credentials loaded)` error when running `terraform apply`, please run `gcloud auth application-default login` and try again.

Expected output:

```
kubernetes_cluster_names = {
  "dev" = "apollo-supergraph-k8s-dev"
  "prod" = "apollo-supergraph-k8s-prod"
}
repo = "https://github.com/you/reference-architecture"
```

<details>
  <summary>What does this do?</summary>

Terraform provisions:

- Two Kubernetes clusters (dev and prod)
- The GitHub repository (`<your org>/reference-architecture`)
- GitHub action secrets for GCP/AWS and Apollo credentials

The subgraph repos are configured to build and deploy to the `dev` cluster once they're provisioned. (The deploy will fail the first time. See "Note about "initial commit" errors" below.)

</details>

### Run cluster setup script

After creating the necessary clusters, you will need to run the included cluster setup script:

```sh
# for example, if using GCP
cd terraform/gcp
./setup_clusters.sh # takes about 2 minutes
```

<details>
  <summary>What does this do?</summary>

For both `dev` and `prod` clusters:

- Configures your local `kubectl` environment so you can inspect your clusters
- For GCP users:
  - Configures namespace, service account, and role bindings for Open Telemetry and Google Traces.
- For AWS users:
  - Configures load balancer controller policy and IAM service account

</details>

After this completes, you're ready to deploy your subgraphs!

## Part C: Deploy applications

<!---
  TODO: Add section for minikube support
-->

### Deploy subgraphs to dev

```sh
gh workflow run "Merge to Main" --repo $GITHUB_ORG/reference-architecture
# this deploys a dependency for prod, see note below
gh workflow run "Deploy Open Telemetry Collector" --repo $GITHUB_ORG/reference-architecture
```

<details>
  <summary>Note about "initial commit" errors</summary>

When terraform creates the repositories, they immediately kick off initial workflow runs. But as the secrets needed are not available at that point, the "initial commit" runs will fail. As a result, we're just re-running them with the commands above to ensure the environments are correctly deployed.

</details>

You can try out a subgraph using port forwarding:

```sh
kubectx apollo-supergraph-k8s-dev
kubectl port-forward service/graphql -n checkout 4001:4001
```

Then visit [http://localhost:4001/](http://localhost:4001/).

### Deploy subgraphs to prod

Commits to the `main` branch of the subgraph repos are automatically built and deployed to the `dev` cluster. To deploy to prod, run the deploy actions:

```sh
  gh workflow run "Manual Deploy - Subgraphs" --repo $GITHUB_ORG/reference-architecture \
    -f version=main \
    -f environment=prod \
    -f dry-run=false \
    -f debug=false
```

```sh
kubectx apollo-supergraph-k8s-prod
kubectl port-forward service/graphql -n checkout 4001:4001
```

Then visit [http://localhost:4001/](http://localhost:4001/). You've successfully deployed your subgraphs! The next step is to deploy the Apollo Router and Coprocessor. 


### Deploy the coprocessor and router

To do so, we'll need to run:

```sh
gh workflow run "Deploy Coprocessor" --repo $GITHUB_ORG/reference-architecture \
  -f environment=dev \
  -f dry-run=false \
  -f debug=false

gh workflow run "Deploy Coprocessor" --repo $GITHUB_ORG/reference-architecture \
  -f environment=prod \
  -f dry-run=false \
  -f debug=false
```

First, and once the deploy completes, we'll deploy the router:

```sh
gh workflow run "Deploy Router" --repo $GITHUB_ORG/reference-architecture \
  -f environment=dev \
  -f dry-run=false \
  -f debug=false

gh workflow run "Deploy Router" --repo $GITHUB_ORG/reference-architecture \
  -f environment=prod \
  -f dry-run=false \
  -f debug=false
```

Which will deploy the router and coprocessor into both environments (`dev` and `prod`), as well as an ingress to access the router on both. In the case of AWS, it will be a domain name, and in the case of GCP, it'll be an IP. 

Follow the below instructions for your cloud provider you are using. Please note that for both providers, the value for the ingress may take some time to become live, so you may need to give it a few minutes to process. 

#### <image src="../images/gcp.svg" height="13" style="margin:auto;" /> GCP

```sh
kubectx apollo-supergraph-k8s-prod
ROUTER_HOSTNAME=http://$(kubectl get ingress -n router -o jsonpath="{.*.*.status.loadBalancer.ingress.*.ip}")
open $ROUTER_HOSTNAME
```

#### <image src="../images/aws.svg" height="13" style="margin:auto;" /> AWS

```sh
kubectx apollo-supergraph-k8s-prod
ROUTER_HOSTNAME=$(kubectl get ingress -n router -o jsonpath="{.*.*.status.loadBalancer.ingress.*.hostname}")
open http://$ROUTER_HOSTNAME
```

Upon running the above commands, you'll have the Router page open and you can make requests against your newly deployed supergraph!

**Note**: If using Explorer to run operations, you will need to set the client headers first:
```
apollographql-client-name:apollo-client
apollographql-client-version:b  
```

### Deploy the client

The last step to getting fully configured is to deploy the client to both environments. To do so, we'll need our router ingress URL to point the client to. This can be pulled from the prior commands, so if you are using the same terminal session, feel free to skip the next set of commands. 

#### <image src="../images/gcp.svg" height="13" style="margin:auto;" /> GCP

```sh
kubectx apollo-supergraph-k8s-prod
ROUTER_HOSTNAME=http://$(kubectl get ingress -n router -o jsonpath="{.*.*.status.loadBalancer.ingress.*.ip}")
```

Upon running the above commands, you'll have the Router page open and you can make requests against your newly deployed supergraph! 

#### <image src="../images/aws.svg" height="13" style="margin:auto;" /> AWS

```sh
kubectx apollo-supergraph-k8s-prod
ROUTER_HOSTNAME=$(kubectl get ingress -n router -o jsonpath="{.*.*.status.loadBalancer.ingress.*.hostname}")
```

Once you have the router hostname, you'll need to set it as a secret in the GitHub repository created.

```sh
  gh variable set BACKEND_URL --body "$ROUTER_HOSTNAME" --repo $GITHUB_ORG/reference-architecture
```

Lastly, we'll need to deploy the client:

```sh
gh workflow run "Deploy Client" --repo $GITHUB_ORG/reference-architecture \
  -f environment=prod \
  -f dry-run=false \
  -f debug=false
```

This will create another ingress specific to the client, so much like the router, you can run the following commands depending on your provider. As with the other ingress, this may take a few minutes to become active. 

#### <image src="../images/gcp.svg" height="13" style="margin:auto;" /> GCP

```sh
kubectx apollo-supergraph-k8s-prod
ROUTER_IP=$(kubectl get ingress -n client -o jsonpath="{.*.*.status.loadBalancer.ingress.*.ip}")
open http://$ROUTER_IP
```

You should now have the full architecture deployed!

#### <image src="../images/aws.svg" height="13" style="margin:auto;" /> AWS

```sh
kubectx apollo-supergraph-k8s-prod
ROUTER_HOSTNAME=$(kubectl get ingress -n client -o jsonpath="{.*.*.status.loadBalancer.ingress.*.hostname}")
open http://$ROUTER_HOSTNAME
```

You should now have the full architecture deployed!