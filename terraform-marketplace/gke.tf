# Cluster selection: existing cluster by default (the customer picks where
# ASP runs), opt-in creation of a dedicated cluster via our vendored gke
# module (wraps terraform-google-modules/kubernetes-engine//modules/private-cluster).

module "gke" {
  count  = var.create_cluster ? 1 : 0
  source = "./modules/gke"

  project_id  = var.project_id
  project     = var.name_prefix
  environment = var.environment
  region      = var.region

  cluster_name       = var.cluster_name != "" ? var.cluster_name : null
  kubernetes_version = var.kubernetes_version
  regional           = var.regional
  zones              = var.zones

  networking_config = {
    network           = local.network_name
    subnetwork        = local.subnetwork_name
    ip_range_pods     = local.ip_range_pods
    ip_range_services = local.ip_range_services
  }

  node_pools = var.node_pools

  enable_private_nodes    = true
  enable_private_endpoint = false
  identity_namespace      = "enabled"

  enable_apis = false

  depends_on = [module.project_services]
}

data "google_container_cluster" "existing" {
  count    = var.create_cluster ? 0 : 1
  name     = var.cluster_name
  location = var.cluster_location != "" ? var.cluster_location : var.region
  project  = var.project_id

  depends_on = [module.project_services]
}

locals {
  cluster_name     = var.create_cluster ? module.gke[0].cluster_name : var.cluster_name
  cluster_endpoint = var.create_cluster ? "https://${module.gke[0].endpoint}" : "https://${data.google_container_cluster.existing[0].endpoint}"
  cluster_ca       = var.create_cluster ? base64decode(module.gke[0].cluster_ca_certificate) : base64decode(data.google_container_cluster.existing[0].master_auth[0].cluster_ca_certificate)
}
