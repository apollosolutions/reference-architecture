provider "github" {
  token = var.github_token
}

# Infra repo for Router, Otel, load testing
resource "github_repository" "repo" {
  name        = "reference-architecture"
  description = "Apollo reference architecture repository"
  visibility  = "public"
  template {
    owner      = "apollosolutions"
    repository = "reference-architecture"
  }
}

### GH Action Secrets ###

# infra repo secrets: the only different value is GCP_CREDENTIALS
resource "github_actions_secret" "apollo_graph_id" {
  repository      = github_repository.repo.name
  secret_name     = "APOLLO_GRAPH_ID"
  plaintext_value = var.apollo_graph_id
}
resource "github_actions_secret" "apollo_key" {
  repository      = github_repository.repo.name
  secret_name     = "APOLLO_KEY"
  plaintext_value = var.apollo_key
}
resource "github_actions_secret" "pq_dev_id" {
  repository      = github_repository.repo.name
  secret_name     = "APOLLO_PQ_DEV_ID"
  plaintext_value = var.pq_dev_id
}
resource "github_actions_secret" "pq_prod_id" {
  repository      = github_repository.repo.name
  secret_name     = "APOLLO_PQ_PROD_ID"
  plaintext_value = var.pq_prod_id
}
