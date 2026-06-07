output "cluster_name" {
  description = "GKE cluster running ASP"
  value       = local.cluster_name
}

output "cluster_location" {
  description = "GKE cluster location"
  value       = var.create_cluster ? var.region : (var.cluster_location != "" ? var.cluster_location : var.region)
}

output "network_name" {
  description = "VPC network used by the deployment"
  value       = local.network_name
}

output "sql_instance" {
  description = "Cloud SQL instance name (managed PostgreSQL)"
  value       = module.cloudsql.instance_name
}

output "sql_private_ip" {
  description = "Private IP the app uses to reach Cloud SQL"
  value       = module.cloudsql.private_ip_address
}

output "domain" {
  description = "Configured public domain for the chat UI. After deploy, point its DNS A record at the Ingress IP shown by: kubectl get ingress -n <namespace>"
  value       = var.domain
}

output "namespace" {
  description = "Kubernetes namespace ASP is installed in"
  value       = local.namespace
}

output "project_id" {
  description = "GCP project ID"
  value       = var.project_id
}
