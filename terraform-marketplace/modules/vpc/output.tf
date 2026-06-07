#=======================
# VPC Network
#=======================
output "network_id" {
  description = "The ID of the VPC network."
  value       = module.vpc.network_id
}

output "base_cidr" {
  description = "The base CIDR block for the VPC network."
  value       = var.base_cidr
}

output "network_self_link" {
  description = "The URI of the VPC network."
  value       = module.vpc.network_self_link
}

output "network_name" {
  description = "The name of the VPC network."
  value       = module.vpc.network_name
}

#=======================
# Subnets
#=======================

output "subnets" {
  description = "List of subnet objects created."
  value       = module.vpc.subnets
}

output "subnets_names" {
  description = "List of subnet names."
  value       = [for s in values(module.vpc.subnets) : s.name if contains(local.subnet_purpose_groups.primary, s.purpose)]
}

output "proxy_subnets_names" {
  description = "List of proxy subnet names."
  value       = [for s in values(module.vpc.subnets) : s.name if contains(local.subnet_purpose_groups.proxy, s.purpose)]
}

output "subnets_secondary_ranges" {
  description = "Map of subnet secondary ranges."
  value       = module.vpc.subnets_secondary_ranges
}

output "subnets_secondary_ranges_gke_pods" {
  description = "List of all subnet secondary range names for GKE pods."
  value = [
    for name in flatten([
      for s in values(module.vpc.subnets) : [
        for r in s.secondary_ip_range : r.range_name if can(regex("-pods$", r.range_name))
      ]
    ]) : name
  ]
}

output "subnets_secondary_ranges_gke_pods_ips" {
  description = "List of all subnet secondary range IPs for GKE pods."
  value = [
    for ip in flatten([
      for s in values(module.vpc.subnets) : [
        for r in s.secondary_ip_range : r.ip_cidr_range if can(regex("-pods$", r.range_name))
      ]
    ]) : ip
  ]
}

output "subnets_secondary_ranges_gke_services" {
  description = "List of all subnet secondary range names for GKE services."
  value = [
    for name in flatten([
      for s in values(module.vpc.subnets) : [
        for r in s.secondary_ip_range : r.range_name if can(regex("-services$", r.range_name))
      ]
    ]) : name
  ]
}

output "subnets_secondary_ranges_gke_services_ips" {

  value = [
    for ip in flatten([
      for s in values(module.vpc.subnets) : [
        for r in s.secondary_ip_range : r.ip_cidr_range if can(regex("-services$", r.range_name))
      ]
    ]) : ip
  ]
}

output "subnets_ips" {
  description = "List of subnet IP CIDR ranges."
  value       = module.vpc.subnets_ips
}

output "subnets_regions" {
  description = "List of subnet regions."
  value       = module.vpc.subnets_regions
}

output "subnets_self_links" {
  description = "List of subnet self links for primary subnets."
  value = [
    for s in values(module.vpc.subnets) : s.self_link
    if contains(local.subnet_purpose_groups.primary, s.purpose)
  ]
}

output "subnets_self_links_proxy" {
  description = "List of subnet self links for proxy subnets."
  value = [
    for s in values(module.vpc.subnets) : s.self_link
    if contains(local.subnet_purpose_groups.proxy, s.purpose)
  ]
}

#====================
# Static IPs
#====================

output "static_ips" {
  description = "Map of static IP addresses created, including names and self links."
  value = {
    for ip in google_compute_address.static_ips :
    ip.name => {
      address      = ip.address
      self_link    = ip.self_link
      region       = ip.region
      address_type = ip.address_type
      network_tier = ip.network_tier
      subnetwork   = try(ip.subnetwork, null)
      network      = try(ip.network, null)
      labels       = try(ip.labels, null)
    }
  }
}

#=======================
# Cloud Routers
#=======================
output "cloud_routers" {
  description = "Map of Cloud Router outputs (router and nat) keyed by region."
  value = {
    for region, router in module.cloud-router :
    region => {
      router = router.router
      nat    = router.nat
    }
  }
}

#=======================
# Cloud NAT
#=======================

output "cloud_nat" {
  description = "Complete Cloud NAT configuration with all computed attributes, grouped views, and filtered outputs."
  value = {
    # Main NAT instances with all attributes
    instances = {
      for name, nat in google_compute_router_nat.nats :
      name => {
        # Basic information
        name    = nat.name
        project = nat.project
        region  = nat.region
        router  = nat.router

        # NAT configuration
        nat_ip_allocate_option             = nat.nat_ip_allocate_option
        source_subnetwork_ip_ranges_to_nat = nat.source_subnetwork_ip_ranges_to_nat
        nat_ips                            = nat.nat_ips
        drain_nat_ips                      = try(nat.drain_nat_ips, [])
        min_ports_per_vm                   = nat.min_ports_per_vm
        max_ports_per_vm                   = try(nat.max_ports_per_vm, null)

        # Timeout configurations
        udp_idle_timeout_sec             = try(nat.udp_idle_timeout_sec, null)
        icmp_idle_timeout_sec            = try(nat.icmp_idle_timeout_sec, null)
        tcp_established_idle_timeout_sec = nat.tcp_established_idle_timeout_sec
        tcp_transitory_idle_timeout_sec  = try(nat.tcp_transitory_idle_timeout_sec, null)
        tcp_time_wait_timeout_sec        = nat.tcp_time_wait_timeout_sec

        # Feature flags
        enable_endpoint_independent_mapping = nat.enable_endpoint_independent_mapping
        enable_dynamic_port_allocation      = nat.enable_dynamic_port_allocation

        # Logging configuration
        log_config = nat.log_config

        # Subnetworks
        subnetwork = nat.subnetwork

        # NAT Rules
        rules = try(nat.rules, [])

        # Resource identifiers
        id = nat.id
      }
    }

    # Grouped by region
    by_region = {
      for region in distinct([for nat in google_compute_router_nat.nats : nat.region]) :
      region => {
        for name, nat in google_compute_router_nat.nats :
        name => {
          name       = nat.name
          router     = nat.router
          nat_ips    = nat.nat_ips
          id         = nat.id
          rules      = try(nat.rules, [])
          log_config = nat.log_config
        } if nat.region == region
      }
    }

    # NATs with rules only
    with_rules = {
      for name, nat in google_compute_router_nat.nats :
      name => {
        name    = nat.name
        region  = nat.region
        router  = nat.router
        nat_ips = nat.nat_ips
        rules   = nat.rules
        id      = nat.id
      } if length(try(nat.rules, [])) > 0
    }

    # All NAT IPs
    nat_ips = {
      for name, nat in google_compute_router_nat.nats :
      name => {
        name          = nat.name
        region        = nat.region
        nat_ips       = nat.nat_ips
        drain_nat_ips = try(nat.drain_nat_ips, [])
      }
    }

    # Summary statistics
    summary = {
      total_nats = length(google_compute_router_nat.nats)
      nats_with_rules = length({
        for name, nat in google_compute_router_nat.nats :
        name => nat if length(try(nat.rules, [])) > 0
      })
      regions = distinct([for nat in google_compute_router_nat.nats : nat.region])
      total_nat_ips = sum([
        for nat in google_compute_router_nat.nats :
        length(nat.nat_ips)
      ])
    }
  }
}

#=======================
# Private Service Access
#=======================

output "private_service_access_name" {
  description = "The name of the address resource for Private Service Access."
  value       = try(google_compute_global_address.private_service_access[0].name, null)
}

output "private_service_access_address" {
  description = "The address resource for Private Service Access."
  value       = try(google_compute_global_address.private_service_access[0].address, null)
}

output "private_service_access_peering_name" {
  description = "The name of the address resource for Private Service Access."
  value       = try(google_compute_global_address.private_service_access[0].name, null)
}

output "private_service_access_network" {
  description = "The service networking connection for Private Service Access."
  value       = try(google_compute_global_address.private_service_access[0].network, null)
}

output "private_service_access_id" {
  description = "The ID of the Private Service Access connection."
  value       = try(google_compute_global_address.private_service_access[0].id, null)
}

output "private_service_access_self_link" {
  description = "The self link of the Private Service Access connection."
  value       = try(google_compute_global_address.private_service_access[0].self_link, null)
}

output "private_service_access_connection_service" {
  description = "Provider peering service that is managing peering connectivity for a service provider organization."
  value       = try(google_service_networking_connection.private_service_access[0].service, null)
}

output "private_service_access_connection_reserved_peering_ranges" {
  description = "Named IP address range(s) of PEERING type reserved for this service provider."
  value       = try(google_service_networking_connection.private_service_access[0].reserved_peering_ranges, null)
}

output "private_service_access_connection_peering" {
  description = "The name of the VPC Network Peering connection that was created by the service producer."
  value       = try(google_service_networking_connection.private_service_access[0].peering, null)
}
