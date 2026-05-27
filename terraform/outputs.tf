output "cluster_name" {
  value = google_container_cluster.gke.name
}

output "cluster_location" {
  value = google_container_cluster.gke.location
}

output "db_connection_name" {
  value = google_sql_database_instance.pg.connection_name
}

output "db_private_ip" {
  value = google_sql_database_instance.pg.private_ip_address
}

output "redis_host" {
  value = google_redis_instance.cache.host
}

output "gateway_ip" {
  value = google_compute_global_address.ingress.address
}
