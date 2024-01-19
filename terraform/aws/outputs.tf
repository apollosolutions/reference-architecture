output "kubernetes_dev" {
  value       = module.eks_dev.cluster_name
  description = "Dev K8s Cluster"
}

output "kubernetes_prod" {
  value       = module.eks_prod.cluster_name
  description = "Prod K8s Cluster"
}

output "repo" {
  value       = github_repository.repo.html_url
  description = "Repository URL"
}
