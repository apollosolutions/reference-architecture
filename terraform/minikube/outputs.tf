output "repo" {
  value       = github_repository.repo.html_url
  description = "Infra (router, o11y) repo URLs"
}

resource "local_file" "repo_env_file"{
  content = <<EOF
export APOLLO_KEY=${var.apollo_key}
export APOLLO_GRAPH_REF=${var.apollo_graph_id}@dev
EOF
  filename = ".repo.env"
}