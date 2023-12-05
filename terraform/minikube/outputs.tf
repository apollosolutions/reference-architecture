output "subgraph_repos" {
  value = {
    for k, v in github_repository.subgraph_repos : k => v.html_url
  }
  description = "Subgraph repo URLs"
}

output "repo_infra" {
  value       = github_repository.infra_repo.html_url
  description = "Infra (router, o11y) repo URLs"
}

resource "local_file" "repo_env_file"{
  content = <<EOF
export APOLLO_KEY=${var.apollo_key}
export APOLLO_GRAPH_REF=${var.apollo_graph_id}@dev
EOF
  filename = ".repo.env"
}