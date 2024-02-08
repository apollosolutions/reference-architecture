provider "github" {
  token = var.github_token
}

# Repository
resource "github_repository" "repo" {
  name        = "reference-architecture"
  description = "Apollo supergraph reference architecture repository"
  visibility  = "public"
  depends_on = [
    module.eks_dev,
    module.eks_prod,
  ]
  template {
    owner      = "apollosolutions"
    repository = "reference-architecture"
  }
}

### GH Action Secrets ###

# repo secrets
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
resource "github_actions_secret" "aws_access_key" {
  repository      = github_repository.repo.name
  secret_name     = "AWS_ACCESS_KEY"
  plaintext_value = aws_iam_access_key.eks_user_key.id
}
resource "github_actions_secret" "aws_secret_key" {
  repository      = github_repository.repo.name
  secret_name     = "AWS_SECRET_KEY"
  plaintext_value = aws_iam_access_key.eks_user_key.secret
}
