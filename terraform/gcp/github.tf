provider "github" {
  token = var.github_token
}

# Infra repo for Router, Otel, load testing
resource "github_repository" "repo" {
  name        = "reference-architecture"
  description = "Apollo supergraph reference architecture repository"
  visibility  = "public"
  depends_on = [
    module.gke
  ]
  template {
    owner      = "apollosolutions"
    repository = "reference-architecture"
  }
}

### Github -> GKE Serivce Accounts and credentials ###

# "Service Agent" credentials for infra repo (so it can manage more resources like cluster roles)
resource "google_service_account" "github-manage-gsa" {
  project      = var.project_id
  account_id   = "${substr(var.demo_name, 0, 12)}-github-manage-gsa"
  display_name = "${substr(var.demo_name, 0, 12)}-github-manage-gsa"
}
resource "google_project_iam_member" "github-manage-admin" {
  project = var.project_id
  role    = "roles/container.serviceAgent"
  member  = "serviceAccount:${google_service_account.github-manage-gsa.email}"
}
resource "google_service_account_key" "github-manage-key" {
  service_account_id = google_service_account.github-manage-gsa.name
}
resource "local_file" "github-manage-key" {
  content  = base64decode(google_service_account_key.github-manage-key.private_key)
  filename = "${path.module}/github-manage-key.json"
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
resource "github_actions_secret" "cluster_prefix" {
  repository      = github_repository.repo.name
  secret_name     = "CLUSTER_PREFIX"
  plaintext_value = var.demo_name
}
resource "github_actions_secret" "gcp_secret" {
  repository      = github_repository.repo.name
  secret_name     = "GCP_CREDENTIALS"
  plaintext_value = base64decode(google_service_account_key.github-manage-key.private_key)
}
