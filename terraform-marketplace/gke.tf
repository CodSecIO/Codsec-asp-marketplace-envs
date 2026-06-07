# Cluster selection: existing cluster by default (the customer picks where
# ASP runs), opt-in creation of a dedicated cluster via our vendored gke
# module (wraps terraform-google-modules/kubernetes-engine//modules/private-cluster).

locals {
  # Built from primitive variables - the Deploy Config UI cannot render
  # complex types, so the pool map is not a customer-facing input.
  node_pools = {
    "asp-pool" = {
      machine_type    = var.node_machine_type
      total_min_count = var.node_min_count
      total_max_count = var.node_max_count
      autoscaling     = true
      # Surge-upgrade settings are coalesced against global_node_pools_config,
      # whose defaults are null - both sides null is a plan-time error, so set
      # them here (standard GKE defaults).
      max_surge       = 1
      max_unavailable = 0
    }
  }
}

module "gke" {
  count  = var.create_cluster ? 1 : 0
  source = "./modules/gke"

  project_id  = var.project_id
  project     = var.goog_cm_deployment_name
  environment = var.environment
  region      = var.region

  cluster_name       = var.cluster_name != "" ? var.cluster_name : null
  kubernetes_version = var.kubernetes_version
  regional           = var.regional
  zones              = var.zone != "" ? [var.zone] : []

  networking_config = {
    network           = local.network_name
    subnetwork        = local.subnetwork_name
    ip_range_pods     = local.ip_range_pods
    ip_range_services = local.ip_range_services
  }

  node_pools = local.node_pools

  enable_private_nodes    = true
  enable_private_endpoint = false
  identity_namespace      = "enabled"

  enable_apis = false

  depends_on = [module.project_services]
}

# Only read when an existing cluster is actually named - an empty name is a
# plan-time error, and the validation harness may run with bare defaults.
# The helm_release precondition enforces "create or name a cluster" at apply.
data "google_container_cluster" "existing" {
  count    = !var.create_cluster && var.cluster_name != "" ? 1 : 0
  name     = var.cluster_name
  location = var.cluster_location != "" ? var.cluster_location : var.region
  project  = var.project_id

  depends_on = [module.project_services]
}

locals {
  cluster_name = var.create_cluster ? module.gke[0].cluster_name : var.cluster_name
  cluster_endpoint = (
    var.create_cluster ? "https://${module.gke[0].endpoint}" :
    var.cluster_name != "" ? "https://${data.google_container_cluster.existing[0].endpoint}" :
    "https://cluster-not-configured.invalid"
  )
  cluster_ca = (
    var.create_cluster ? base64decode(module.gke[0].cluster_ca_certificate) :
    var.cluster_name != "" ? base64decode(data.google_container_cluster.existing[0].master_auth[0].cluster_ca_certificate) :
    ""
  )
}
