data "google_client_config" "default" {}

# Get available zones in the region
data "google_compute_zones" "available" {
  region  = var.region
  project = var.project_id
}
