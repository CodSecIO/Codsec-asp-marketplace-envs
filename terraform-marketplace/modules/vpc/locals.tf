locals {
  # Unified name prefix for networking resources
  name_prefix = can(regex("(^|-)${var.environment}(-|$)", var.project)) ? var.project : "${var.project}-${var.environment}"

  #=======================
  # Subnet Configuration
  #=======================

  # Define subnet purpose groups
  subnet_purpose_groups = {
    primary = ["PRIVATE", "PUBLIC"] # Regular subnets that can have secondary ranges
    proxy   = ["REGIONAL_MANAGED_PROXY", "GLOBAL_MANAGED_PROXY"]
  }

  subnet_cidr_sizes = {
    primary_subnets        = 20 # 4,096 IPs
    gke_pods               = 20 # 4,096 IPs
    gke_services           = 22 # 1,024 IPs
    proxy                  = 24 # 256 IPs
    private_service_access = 20 # 4,096 IPs
  }

  subnet_counts = {
    primary = length(var.primary_subnets)
    proxy   = length(var.proxy_subnets)
  }

  # Define subnet type allocations with explicit ranges
  subnet_allocations = {
    primary_subnets = {
      count       = local.subnet_counts.primary
      start_index = 0 # 10.0.0.0/20, 10.0.16.0/20,
      size        = local.subnet_cidr_sizes.primary_subnets
    }
    gke_pods = {
      count       = var.enable_gke_secondary_ranges ? local.subnet_counts.primary : 0
      start_index = 5 # 10.0.80.0/20, 10.0.96.0/20,
      size        = local.subnet_cidr_sizes.gke_pods
    }
    additional_gke_pods = {
      count       = var.enable_gke_secondary_ranges ? local.subnet_counts.primary : 0
      start_index = 12
      size        = local.subnet_cidr_sizes.gke_pods
    }
    gke_services = {
      count       = var.enable_gke_secondary_ranges ? local.subnet_counts.primary : 0
      start_index = 40 # 10.0.160.0/22, 10.0.160.0/22
      size        = local.subnet_cidr_sizes.gke_services
    }
    proxy = {
      count       = local.subnet_counts.proxy
      start_index = 180 # 10.0.180.0/24, 10.0.181.0/24,
      size        = local.subnet_cidr_sizes.proxy
    }
  }

  # Map of subnet name to CIDR for primary subnets
  # Example (base_cidr = 10.0.0.0/16, primary_subnets = ["subnet-1", "subnet-2", ...]):
  # subnet-1: 10.0.0.0/20
  # subnet-2: 10.0.16.0/20
  # subnet-3: 10.0.32.0/20
  # subnet-4: 10.0.48.0/20
  primary_cidrs = {
    for name, subnet in var.primary_subnets :
    name => cidrsubnet(
      var.base_cidr,
      local.subnet_cidr_sizes.primary_subnets - split("/", var.base_cidr)[1],
      (tonumber(regex("[0-9]+$", name)) - 1) + local.subnet_allocations.primary_subnets.start_index
    )
  }

  # Map of subnet name to CIDR for proxy subnets
  # Example (base_cidr = 10.0.0.0/16, proxy_subnets = ["proxy-1", "proxy-2", ...]):
  # proxy-1: 10.0.180.0/24
  # proxy-2: 10.0.181.0/24
  # proxy-3: 10.0.182.0/24
  # proxy-4: 10.0.183.0/24
  proxy_cidrs = {
    for name, subnet in var.proxy_subnets :
    name => cidrsubnet(
      var.base_cidr,
      local.subnet_cidr_sizes.proxy - split("/", var.base_cidr)[1],
      (tonumber(regex("[0-9]+$", name)) - 1) + local.subnet_allocations.proxy.start_index
    )
  }

  # Map of primary subnet name to GKE pods secondary CIDR
  # Example (base_cidr = 10.0.0.0/16, primary_subnets = ["subnet-1", "subnet-2", ...]):
  # subnet-1: 10.0.80.0/20
  # subnet-2: 10.0.96.0/20
  # subnet-3: 10.0.112.0/20
  # subnet-4: 10.0.128.0/20
  gke_pods_cidrs = {
    for name, subnet in var.primary_subnets :
    name => cidrsubnet(
      var.base_cidr,
      local.subnet_cidr_sizes.gke_pods - split("/", var.base_cidr)[1],
      (tonumber(regex("[0-9]+$", name)) - 1) + local.subnet_allocations.gke_pods.start_index
    )
  }

  # Map of primary subnet name to GKE services secondary CIDR
  # Example (base_cidr = 10.0.0.0/16, primary_subnets = ["subnet-1", "subnet-2", ...]):
  # subnet-1: 10.0.40.0/22
  # subnet-2: 10.0.44.0/22
  # subnet-3: 10.0.48.0/22
  # subnet-4: 10.0.52.0/22
  gke_services_cidrs = {
    for name, subnet in var.primary_subnets :
    name => cidrsubnet(
      var.base_cidr,
      local.subnet_cidr_sizes.gke_services - split("/", var.base_cidr)[1],
      (tonumber(regex("[0-9]+$", name)) - 1) + local.subnet_allocations.gke_services.start_index
    )
  }

  # Map of primary subnet name to additional GKE pods secondary CIDRs
  # Creates N additional ranges per subnet based on additional_ip_range_pods number
  additional_gke_pods_cidrs = {
    for name, subnet in var.primary_subnets :
    name => coalesce(subnet.additional_ip_range_pods, 0) > 0 ? [
      for i in range(coalesce(subnet.additional_ip_range_pods, 0)) :
      cidrsubnet(
        var.base_cidr,
        local.subnet_cidr_sizes.gke_pods - split("/", var.base_cidr)[1],
        (tonumber(regex("[0-9]+$", name)) - 1) + local.subnet_allocations.additional_gke_pods.start_index + i
      )
    ] : []
  }

  # Merge all primary and proxy subnets into a single list with a name field
  all_subnets = flatten([
    [for name, subnet in var.primary_subnets : merge(subnet, { name = name })],
    [for name, subnet in var.proxy_subnets : merge(subnet, { name = name })]
  ])

  # Construct the subnets list for the module
  subnets = [
    for subnet in local.all_subnets : {
      subnet_name                      = subnet.name
      subnet_ip                        = contains(local.subnet_purpose_groups.primary, subnet.purpose) ? local.primary_cidrs[subnet.name] : local.proxy_cidrs[subnet.name]
      subnet_region                    = subnet.region
      purpose                          = subnet.purpose
      role                             = contains(local.subnet_purpose_groups.proxy, subnet.purpose) ? subnet.role : null
      description                      = try(subnet.description, "Subnet ${subnet.purpose == "PRIVATE" ? "private" : subnet.purpose == "PUBLIC" ? "public" : null} for ${try(subnet.region, var.region)}")
      subnet_private_access            = contains(local.subnet_purpose_groups.primary, subnet.purpose) ? "true" : null
      subnet_flow_logs                 = contains(local.subnet_purpose_groups.primary, subnet.purpose) ? (try(subnet.flow_logs.enabled, var.default_flow_logs_config.enabled) ? "true" : null) : null
      subnet_flow_logs_interval        = contains(local.subnet_purpose_groups.primary, subnet.purpose) ? try(subnet.flow_logs.interval, var.default_flow_logs_config.interval) : null
      subnet_flow_logs_sampling        = contains(local.subnet_purpose_groups.primary, subnet.purpose) ? try(subnet.flow_logs.sampling, var.default_flow_logs_config.sampling) : null
      subnet_flow_logs_metadata        = contains(local.subnet_purpose_groups.primary, subnet.purpose) ? try(subnet.flow_logs.metadata, var.default_flow_logs_config.metadata) : null
      subnet_flow_logs_filter          = contains(local.subnet_purpose_groups.primary, subnet.purpose) ? try(subnet.flow_logs.filter, var.default_flow_logs_config.filter) : null
      subnet_flow_logs_metadata_fields = contains(local.subnet_purpose_groups.primary, subnet.purpose) ? try(subnet.flow_logs.metadata_fields, var.default_flow_logs_config.metadata_fields) : null
      stack_type                       = "IPV4_ONLY"
    }
  ]

  # Calculate secondary ranges for GKE using robust CIDR maps
  primary_subnets = [
    for s in local.subnets : s if contains(local.subnet_purpose_groups.primary, s.purpose)
  ]

  secondary_ranges = var.enable_gke_secondary_ranges ? {
    for subnet in local.primary_subnets :
    subnet.subnet_name => concat([
      {
        range_name    = "${subnet.subnet_name}-pods"
        ip_cidr_range = local.gke_pods_cidrs[subnet.subnet_name]
      },
      {
        range_name    = "${subnet.subnet_name}-services"
        ip_cidr_range = local.gke_services_cidrs[subnet.subnet_name]
      }
      ], [
      # Add additional pods ranges if configured
      for i, cidr in local.additional_gke_pods_cidrs[subnet.subnet_name] :
      {
        range_name = try(
          var.primary_subnets[subnet.subnet_name].additional_ip_range_pods_names[i],
          "${subnet.subnet_name}-pods-${i + 2}" # Start from 2 since we already have -pods
        )
        ip_cidr_range = cidr
      }
    ])
  } : {}

  #=======================
  # Routes Configuration
  #=======================

  # Combine and deduplicate routes for the routes module
  routes = {
    for route in var.additional_routes :
    route.name => route
  }

  #=======================
  # Firewall Configuration
  #=======================

  firewall_rules = {
    ingress = distinct(concat(
      [for rule in var.firewall_rules.ingress : {
        for k, v in rule : k => v if v != null
      }]
    )),
    egress = distinct(concat(
      [for rule in var.firewall_rules.egress : {
        for k, v in rule : k => v if v != null
      }]
    ))
  }

  #=======================
  # Static IP Configuration
  #=======================
  static_ips = {
    for ip in var.static_ips :
    ip.name => merge(ip, {
      # Handle address_type limitations automatically
      address_type = try(ip.address_type, "EXTERNAL"),

      # INTERNAL addresses always use PREMIUM network tier (limitation abstraction)
      network_tier = ip.address_type == "INTERNAL" ? "PREMIUM" : try(ip.network_tier, "PREMIUM"),

      # Only include subnetwork for INTERNAL addresses
      subnetwork = ip.address_type == "INTERNAL" ? try(ip.subnetwork, null) : null,

      description = try(ip.description, "Static IP address for ${ip.name}"),
      labels      = try(ip.labels, {})
    })
  }

  #====================
  # Cloud Router & NAT
  #====================

  # Cloud Router configs
  cloud_routers = var.enable_cloud_router ? {
    for region in distinct([for s in local.subnets : s.subnet_region if s.purpose == "PRIVATE"]) : region => {
      region = region
    }
  } : {}

  # Cloud NAT configs
  nat_configs = var.enable_nat ? [
    for region in distinct([for s in local.subnets : s.subnet_region if s.purpose == "PRIVATE"]) : {
      name                               = "${var.project}-${var.environment}-nat-${region}"
      nat_ip_allocate_option             = var.nat_configs.nat_ip_allocate_option
      source_subnetwork_ip_ranges_to_nat = var.nat_configs.source_subnetwork_ip_ranges_to_nat
      subnetworks = [
        for subnet in var.nat_configs.subnetworks : {
          name                     = subnet.name
          source_ip_ranges_to_nat  = subnet.source_ip_ranges_to_nat
          secondary_ip_range_names = try(subnet.secondary_ip_range_names, [])
        } if subnet.subnet_region == region && subnet.purpose == "PRIVATE"
      ]
      region           = region
      nat_ips          = var.nat_configs.nat_ips
      drain_nat_ips    = var.nat_configs.drain_nat_ips
      min_ports_per_vm = var.nat_configs.min_ports_per_vm
      max_ports_per_vm = var.nat_configs.max_ports_per_vm
      # Individual timeout fields (not nested object)
      udp_idle_timeout_sec                = try(var.nat_configs.timeouts.udp_idle_timeout_sec, null)
      icmp_idle_timeout_sec               = try(var.nat_configs.timeouts.icmp_idle_timeout_sec, null)
      tcp_established_idle_timeout_sec    = try(var.nat_configs.timeouts.tcp_established_idle_timeout_sec, null)
      tcp_transitory_idle_timeout_sec     = try(var.nat_configs.timeouts.tcp_transitory_idle_timeout_sec, null)
      tcp_time_wait_timeout_sec           = try(var.nat_configs.timeouts.tcp_time_wait_timeout_sec, null)
      enable_endpoint_independent_mapping = try(var.nat_configs.enable_endpoint_independent_mapping, null)
      enable_dynamic_port_allocation      = try(var.nat_configs.enable_dynamic_port_allocation, null)
      log_config                          = var.nat_configs.log_config
      rules                               = var.nat_configs.rules
    }
  ] : []

}
