# Network selection: existing network by default (the recommended Marketplace
# pattern), opt-in creation of a dedicated VPC via our vendored vpc module.
#
# When create_network = false the customer's network must already have a
# Private Services Access (PSA) connection - Cloud SQL with a private IP
# requires it, and this module deliberately does NOT create PSA on an
# existing network (the peering is shared with other services in the
# project; owning it from an app module is unsafe).
# When create_network = true the vendored vpc module creates the VPC, the
# subnet (with GKE secondary ranges), and PSA on that new, dedicated VPC.

module "vpc" {
  count  = var.create_network ? 1 : 0
  source = "./modules/vpc"

  project_id  = var.project_id
  project     = var.goog_cm_deployment_name
  environment = var.environment
  region      = var.region
  base_cidr   = var.network_cidr

  primary_subnets = {
    "subnet-1" = {
      region                         = var.region
      purpose                        = "PRIVATE"
      description                    = "ASP subnet"
      additional_ip_range_pods       = 0
      additional_ip_range_pods_names = []
    }
  }

  enable_private_service_access = true
  enable_gke_secondary_ranges   = true
  proxy_subnets                 = {}

  depends_on = [module.project_services]
}

data "google_compute_network" "existing" {
  count   = var.create_network ? 0 : 1
  name    = var.network_name
  project = var.project_id

  depends_on = [module.project_services]
}

data "google_compute_subnetwork" "existing" {
  count   = var.create_network ? 0 : 1
  name    = var.subnetwork_name
  region  = var.region
  project = var.project_id

  depends_on = [module.project_services]
}

locals {
  network_name      = var.create_network ? module.vpc[0].network_name : data.google_compute_network.existing[0].name
  network_id        = var.create_network ? module.vpc[0].network_id : data.google_compute_network.existing[0].id
  subnetwork_name   = var.create_network ? module.vpc[0].subnets_names[0] : data.google_compute_subnetwork.existing[0].name
  ip_range_pods     = var.create_network ? module.vpc[0].subnets_secondary_ranges_gke_pods[0] : var.ip_range_pods
  ip_range_services = var.create_network ? module.vpc[0].subnets_secondary_ranges_gke_services[0] : var.ip_range_services
}
