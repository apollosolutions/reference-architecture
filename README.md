# Apollo Federation Supergraph Architecture

This repository contains a reference architecture utilizing [Kubernetes](https://kubernetes.io/docs/concepts/overview/) when using [Apollo Federation](https://www.apollographql.com/docs/federation/). It uses GitHub Actions configured to automate most of the deployment processes for the router, subgraphs, and client, along with minimal observability tooling available to be able to appropriately load test the resulting environment. 

Once the architecture is fully stood up, you'll have: 

- An Apollo Router running utilizing:
  - [Persisted Queries for safelisting operations](https://www.apollographql.com/docs/router/configuration/persisted-queries/#differences-from-automatic-persisted-queries)
  - [A coprocessor for handling customizations outside of the router](https://www.apollographql.com/docs/router/customizations/coprocessor)
  - [Rhai scripts to do basic customizations within the router container](https://www.apollographql.com/docs/router/customizations/rhai)
  - [Authorization/Authentication directives](https://www.apollographql.com/docs/router/configuration/authorization)
- Eight subgraphs, each handling a portion of the overall supergraph schema
- A React-based frontend application utilizing Apollo Client
- GitHub Actions to automate image building and GraphOS-specific implementations, including schema publishing and persisted query manifest creation/publishing
- Tools to run k6 load tests against the architecture from within the same cluster

### The ending architecture

![Software Development Life Cycle](/images/sdlc.png)


### Prerequisites

At a minimum, you will need:

- A Github account.
- An enterprise Apollo GraphOS account.
  - You can use [a free enterprise trial account](https://studio.apollographql.com/signup?type=enterprise-trial) if you don't have an enterprise contract.
- An account for either:
  - Google Cloud Platform (GCP).
  - Amazon Web Services (AWS).

Further requirements are noted within the [setup instructions](./docs/setup.md) as each type of environment (cloud vs. local) requires additional tooling.

## Contents

- ⏱ estimated time: 1 hour 15 minutes
- 💰 estimated cost (if using a cloud provider): $10-$15

### [Setup](/docs/setup.md)

During setup, you'll be:

- Gathering accounts and credentials
- Provisioning resources
- Deploying the applications, including router, subgraphs, client, and observability tools

### [Cleanup](/docs/cleanup.md)

Once finished, you can cleanup your environments following the above document.
