output "kubernetes_cluster_names" {
  value = {
    for k, v in module.gke : k => v.name
  }
  description = "Cluster names for each stage"
}

output "repo" {
  value       = github_repository.repo.html_url
  description = "Respository URL"
}
