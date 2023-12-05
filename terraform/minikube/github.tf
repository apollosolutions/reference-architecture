provider "github" {
  token = var.github_token
}

# Infra repo for Router, Otel, load testing
resource "github_repository" "infra_repo" {
  name        = "${var.demo_name}-infra"
  description = "Apollo K8s Supergraph infrastructure repository"
  visibility  = "public"
  template {
    owner      = "apollosolutions"
    repository = "build-a-supergraph-infra"
  }
}

# Repo for subgraphs
resource "github_repository" "subgraph_repos" {
  for_each = {
    for index, subgraph in var.subgraphs : subgraph.name => subgraph
  }

  name        = "${var.demo_name}-${each.value.name}"
  description = "Apollo K8s Supergraph ${each.value.name} source code repository"
  visibility  = "public"
  template {
    owner      = each.value.template_repo.owner
    repository = each.value.template_repo.repository
  }
}
### GH Action Secrets ###

# subgraphs
resource "github_actions_secret" "subgraph_apollo_graph_secret" {
  for_each = {
    for index, subgraph in var.subgraphs : subgraph.name => subgraph
  }
  repository      = github_repository.subgraph_repos[each.key].name
  secret_name     = "APOLLO_GRAPH_ID"
  plaintext_value = var.apollo_graph_id
}
resource "github_actions_secret" "subgraph_apollo_secret" {
  for_each = {
    for index, subgraph in var.subgraphs : subgraph.name => subgraph
  }
  repository      = github_repository.subgraph_repos[each.key].name
  secret_name     = "APOLLO_KEY"
  plaintext_value = var.apollo_key
}


# infra repo secrets: the only different value is GCP_CREDENTIALS
resource "github_actions_secret" "infra_apollo_graph_secret" {
  repository      = github_repository.infra_repo.name
  secret_name     = "APOLLO_GRAPH_ID"
  plaintext_value = var.apollo_graph_id
}
resource "github_actions_secret" "infra_apollo_secret" {
  repository      = github_repository.infra_repo.name
  secret_name     = "APOLLO_KEY"
  plaintext_value = var.apollo_key
}
