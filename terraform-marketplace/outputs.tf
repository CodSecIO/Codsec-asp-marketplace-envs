output "ingress_ip" {
  description = "Static external IP for the ingress. Point your domain's DNS A record here."
  value       = google_compute_global_address.ingress.address
}

output "domain" {
  description = "The configured public domain for the chat UI."
  value       = var.domain
}

output "cluster_name" {
  description = "Name of the provisioned GKE Autopilot cluster."
  value       = google_container_cluster.gke.name
}

output "cluster_location" {
  description = "Location (region) of the GKE cluster."
  value       = google_container_cluster.gke.location
}

output "sql_instance" {
  description = "Cloud SQL instance name (managed PostgreSQL)."
  value       = google_sql_database_instance.pg.name
}

output "sql_private_ip" {
  description = "Private IP the app uses to reach Cloud SQL."
  value       = google_sql_database_instance.pg.private_ip_address
}
