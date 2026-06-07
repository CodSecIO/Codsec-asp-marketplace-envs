# Cluster Outputs
output "cluster_name" {
  description = "The name of the GKE cluster"
  value       = module.gke.name
}

output "provider_token" {
  description = "The provider token"
  value       = data.google_client_config.default.access_token
  sensitive   = true
}

output "cluster_id" {
  description = "The ID of the GKE cluster"
  value       = module.gke.cluster_id
}

output "cluster_location" {
  description = "The location (region or zone) in which the cluster master will be created"
  value       = module.gke.location
}

output "endpoint" {
  description = "The IP address of the Kubernetes master endpoint"
  value       = module.gke.endpoint
  sensitive   = true
}

output "endpoint_dns" {
  description = "The DNS address of the Kubernetes master endpoint"
  value       = module.gke.endpoint_dns
}

output "cluster_ca_certificate" {
  description = "The public certificate that is the root of trust for the cluster"
  value       = module.gke.ca_certificate
  sensitive   = true
}

output "cluster_master_version" {
  description = "The current version of the master in the cluster"
  value       = module.gke.master_version
}

output "cluster_min_master_version" {
  description = "The minimum version of the master"
  value       = module.gke.min_master_version
}

output "master_ipv4_cidr_block" {
  description = "The IP range in CIDR notation used for the hosted master network"
  value       = module.gke.master_ipv4_cidr_block
}

# Node Pool Outputs
output "node_pools_names" {
  description = "List of node pool names"
  value       = module.gke.node_pools_names
}

output "node_pools_versions" {
  description = "List of node pool versions"
  value       = module.gke.node_pools_versions
}

# Service Account Outputs
output "service_account" {
  description = "The service account to default running nodes as if not overridden in node_pools"
  value       = module.gke.service_account
}

# Security Outputs
output "master_authorized_networks_config" {
  description = "Networks from which access to master is permitted"
  value       = module.gke.master_authorized_networks_config
}

# Identity Outputs
output "identity_service_enabled" {
  description = "Whether Identity Service is enabled"
  value       = module.gke.identity_service_enabled
}

# Additional Cluster Information
output "cluster_resource_labels" {
  description = "The resource labels applied to the cluster"
  value       = local.merged_tags
}

# ComputeClass Outputs
output "compute_class_names" {
  description = "List of ComputeClass names created"
  value       = [for name, _ in var.compute_classes : name]
}

output "compute_class_node_selectors" {
  description = "Map of ComputeClass names to their node selector labels (use with nodeSelector in Pod specs)"
  value = {
    for name, _ in var.compute_classes :
    name => "cloud.google.com/compute-class=${name}"
  }
}
