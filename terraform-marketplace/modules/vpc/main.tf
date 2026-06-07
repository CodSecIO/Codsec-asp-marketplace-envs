#==============================================
# GCP API Enablement
#==============================================

resource "google_project_service" "apis" {
  for_each = var.enable_apis ? toset([
    "compute.googleapis.com",
    "servicenetworking.googleapis.com",
  ]) : toset([])

  project                    = var.project_id
  service                    = each.value
  disable_on_destroy         = false
  disable_dependent_services = false
}

#==============================================
# VPC Network
#==============================================

module "vpc" {
  source = "terraform-google-modules/network/google"
  # Vendored copy: bumped from 11.1.1 - that release caps google < 7 and the
  # vendored gke module requires >= 7.12.
  version = "12.0.0"

  depends_on = [google_project_service.apis]

  network_name = "${local.name_prefix}-network"
  project_id   = var.project_id
  routing_mode = var.routing_mode

  # Configuration options
  delete_default_internet_gateway_routes = var.delete_default_internet_gateway_routes
  mtu                                    = var.mtu
  bgp_always_compare_med                 = var.bgp_always_compare_med
  bgp_best_path_selection_mode           = var.bgp_best_path_selection_mode
  bgp_inter_region_cost                  = var.bgp_inter_region_cost

  # Subnets
  subnets          = local.subnets
  secondary_ranges = local.secondary_ranges

  # Firewall rules
  ingress_rules = local.firewall_rules.ingress
  egress_rules  = local.firewall_rules.egress
}

module "cloud-router" {
  source = "terraform-google-modules/cloud-router/google"
  # Vendored copy: bumped from 7.0.0 (caps google < 7).
  version  = "8.3.0"
  for_each = local.cloud_routers

  name    = "${local.name_prefix}-router-${each.value.region}"
  network = module.vpc.network_id
  # cloud-router 8.x renamed `project` to `project_id`.
  project_id                    = var.project_id
  region                        = each.value.region
  encrypted_interconnect_router = var.encrypted_interconnect_router
  # BGP enables dynamic routing for cross-cloud and on-premises connectivity
  bgp = var.bgp

  # Cloud NAT is managed separately using cloud-nat module for better control

  description = "Cloud Router for ${local.name_prefix}-network in ${each.value.region}"
  depends_on  = [data.google_compute_subnetwork.subnet_status]
}

resource "google_compute_address" "static_ips" {
  for_each = local.static_ips

  # Required arguments
  name         = each.value.name
  description  = try(each.value.description, "Static IP address for ${each.value.name}")
  address      = try(each.value.address, null)
  address_type = each.value.address_type

  # Handle network_tier limitation: INTERNAL addresses cannot specify network_tier
  network_tier = each.value.address_type == "INTERNAL" ? null : each.value.network_tier

  # Only include subnetwork for INTERNAL addresses
  subnetwork = try(each.value.subnetwork, null)
  network    = try(each.value.network, null)
  labels     = try(each.value.labels, {})

  # Timeouts
  dynamic "timeouts" {
    for_each = try(each.value.timeouts, null) != null ? [each.value.timeouts] : []
    content {
      create = try(timeouts.value.create, null)
      delete = try(timeouts.value.delete, null)
    }
  }
}

# Cloud NAT using direct resource with unified configuration for full control
resource "google_compute_router_nat" "nats" {
  for_each = {
    for nat in local.nat_configs :
    "${nat.name}" => nat
  }

  # Basic NAT configuration
  name    = each.value.name
  project = var.project_id
  region  = each.value.region
  router  = module.cloud-router[each.value.region].router.name

  nat_ip_allocate_option              = each.value.nat_ip_allocate_option
  source_subnetwork_ip_ranges_to_nat  = each.value.source_subnetwork_ip_ranges_to_nat
  nat_ips                             = each.value.nat_ips
  min_ports_per_vm                    = each.value.min_ports_per_vm
  tcp_established_idle_timeout_sec    = each.value.tcp_established_idle_timeout_sec
  tcp_time_wait_timeout_sec           = each.value.tcp_time_wait_timeout_sec
  enable_endpoint_independent_mapping = each.value.enable_endpoint_independent_mapping
  enable_dynamic_port_allocation      = each.value.enable_dynamic_port_allocation

  # Logging configuration
  dynamic "log_config" {
    for_each = coalesce(each.value.log_config, {})
    content {
      enable = log_config.value.enable
      filter = log_config.value.filter
    }
  }

  # Subnet configuration
  dynamic "subnetwork" {
    for_each = each.value.subnetworks
    content {
      name                     = subnetwork.value.name
      source_ip_ranges_to_nat  = subnetwork.value.source_ip_ranges_to_nat
      secondary_ip_range_names = try(subnetwork.value.secondary_ip_range_names, [])
    }
  }

  # NAT Rules (empty array for regular NATs, populated for NATs with rules)
  dynamic "rules" {
    for_each = each.value.rules
    content {
      rule_number = rules.value.rule_number
      description = try(rules.value.description, "NAT rule ${rules.value.rule_number}")
      match       = rules.value.match

      action {
        source_nat_active_ips = rules.value.source_nat_active_ips
      }
    }
  }

  depends_on = [module.cloud-router]
}

module "network-routes" {
  source = "terraform-google-modules/network/google//modules/routes"
  # Vendored copy: bumped from 11.1.1 (caps google < 7), matching module.vpc.
  version      = "12.0.0"
  network_name = module.vpc.network_name
  project_id   = var.project_id
  routes       = values(local.routes)
}

# Sets up VPC peering and IP ranges for private service access.
# Note: Service-specific private access (e.g., Cloud SQL) must be configured separately.
resource "google_compute_global_address" "private_service_access" {
  count         = var.enable_private_service_access ? 1 : 0
  name          = "${local.name_prefix}-private-service-access"
  project       = var.project_id
  prefix_length = local.subnet_cidr_sizes.private_service_access
  address_type  = "INTERNAL"
  purpose       = "VPC_PEERING"
  network       = module.vpc.network_id
  description   = "Private Service Access range for ${local.name_prefix}"
}

# Private service connection for VPC peering to GCP Services
resource "google_service_networking_connection" "private_service_access" {
  count                   = var.enable_private_service_access ? 1 : 0
  network                 = module.vpc.network_id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [for psa in google_compute_global_address.private_service_access : psa.name]
}

resource "google_compute_network_peering_routes_config" "private_service_access" {
  count   = var.enable_private_service_access ? 1 : 0
  peering = "servicenetworking-googleapis-com"
  network = module.vpc.network_name
  project = var.project_id

  import_custom_routes = var.psa_import_custom_routes
  export_custom_routes = var.psa_export_custom_routes

  depends_on = [google_service_networking_connection.private_service_access]
}
