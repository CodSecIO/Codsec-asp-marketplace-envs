#================
#   General
#================

variable "enable_apis" {
  description = "Enable required GCP APIs for this module"
  type        = bool
  default     = true
}

variable "project_id" {
  type        = string
  description = "The ID of the project in which the network is created"
  default     = null
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", var.project_id)) && length(var.project_id) >= 6 && length(var.project_id) <= 30 && !can(regex("(google|ssl|undefined|null)", lower(var.project_id)))
    error_message = "The project_id must be 6-30 characters, start with a letter, contain only lowercase letters, numbers, and hyphens, end with a letter or number, and not contain restricted strings."
  }
}

variable "project" {
  type        = string
  description = "The name of the project in which the network is created"
  default     = null
}

variable "environment" {
  type        = string
  description = "The environment of the project in which the network is created"
  default     = null
}

#===================
# VPC Configuration
#===================

variable "region" {
  type        = string
  description = "The region of the project in which the network is created"
  validation {
    condition     = can(regex("^(asia|australia|europe|me|northamerica|southamerica|us)-(central|east|north|northeast|south|southeast|southwest|west)[0-9]+$", var.region))
    error_message = "The region must be a valid GCP region. See https://cloud.google.com/compute/docs/regions-zones for valid regions."
  }
}

variable "primary_subnets" {
  description = "Map of subnet definitions. Keys are subnet names."
  type = map(object({
    region                         = string
    purpose                        = optional(string)
    description                    = optional(string)
    additional_ip_range_pods       = optional(number)
    additional_ip_range_pods_names = optional(list(string))
    flow_logs = optional(object({
      enabled         = optional(bool)
      interval        = optional(string)
      sampling        = optional(number)
      metadata        = optional(string)
      filter          = optional(string)
      metadata_fields = optional(list(string))
    }))
  }))

  # Validate additional_ip_range_pods values
  validation {
    condition = alltrue([
      for name, subnet in var.primary_subnets :
      subnet.additional_ip_range_pods == null || (
        subnet.additional_ip_range_pods >= 0 &&
        subnet.additional_ip_range_pods <= 28
      )
    ])
    error_message = "additional_ip_range_pods must be null or a number between 0 and 28 (limited by available indices 12-39)."
  }

  # Validate additional_ip_range_pods_names match the count
  validation {
    condition = alltrue([
      for name, subnet in var.primary_subnets :
      subnet.additional_ip_range_pods_names == null || (
        subnet.additional_ip_range_pods != null &&
        length(subnet.additional_ip_range_pods_names) <= subnet.additional_ip_range_pods
      )
    ])
    error_message = "additional_ip_range_pods_names cannot exceed the number specified in additional_ip_range_pods."
  }

  # For now we only support 5 primary subnets
  validation {
    condition     = length(var.primary_subnets) <= 5
    error_message = "You can define up to 5 primary subnets."
  }

  # Validate that all subnets have either a valid GCP region or no region (null/empty)
  validation {
    condition = alltrue([
      for subnet in values(var.primary_subnets) :
      subnet.region == null || subnet.region == "" ||
      can(regex("^(asia|australia|europe|me|northamerica|southamerica|us)-(central|east|north|northeast|south|southeast|southwest|west)[0-9]+$", subnet.region))
    ])
    error_message = "All primary subnets must have either a valid GCP region or no region specified. See https://cloud.google.com/compute/docs/regions-zones for valid regions."
  }

  # Validate that all subnets have a valid purpose
  validation {
    condition = alltrue([
      for subnet in values(var.primary_subnets) :
      contains(["PUBLIC", "PRIVATE"], subnet.purpose)
    ])
    error_message = "Each primary subnet purpose must be either 'PUBLIC' or 'PRIVATE'."
  }

  # Validate that all subnets have a valid sequential numbering for cidr assignment
  validation {
    condition = alltrue([
      for key in keys(var.primary_subnets) :
      can(regex(".*-[0-9]+$", key))
      ]) && (
      length(var.primary_subnets) == 0 ? true :
      length([
        for i in range(1, length(var.primary_subnets) + 1) :
        i if length([
          for key in keys(var.primary_subnets) :
          key if can(regex(".*-${i}$", key))
        ]) == 1
      ]) == length(var.primary_subnets)
    )
    error_message = "All subnet keys must end with '-number' and the numbers must be sequential starting from 1 (e.g., subnet-1, subnet-2, subnet-3). Each number from 1 to N must appear exactly once where N is the total number of subnets."
  }
}

variable "proxy_subnets" {
  description = "Map of subnet definitions. Keys are subnet names."
  type = map(object({
    region      = string
    purpose     = string
    role        = string
    description = optional(string)
  }))

  # For now we only support 3 proxy subnets
  validation {
    condition     = length(var.proxy_subnets) <= 3
    error_message = "You can define up to 3 proxy subnets."
  }

  # Validate that all subnets have either a valid GCP region or no region (null/empty)
  validation {
    condition = alltrue([
      for subnet in values(var.proxy_subnets) :
      subnet.region == null || subnet.region == "" ||
      can(regex("^(asia|australia|europe|me|northamerica|southamerica|us)-(central|east|north|northeast|south|southeast|southwest|west)[0-9]+$", subnet.region))
    ])
    error_message = "All proxy subnets must have either a valid GCP region or no region specified. See https://cloud.google.com/compute/docs/regions-zones for valid regions."
  }

  # Validate that all subnets have a valid role
  validation {
    condition = alltrue([
      for subnet in values(var.proxy_subnets) :
      contains(["ACTIVE", "BACKUP"], subnet.role)
    ])
    error_message = "Proxy subnets must have a role set to either 'ACTIVE' or 'BACKUP'."
  }

  # Validate that all subnets have a valid purpose
  validation {
    condition = alltrue([
      for subnet in values(var.proxy_subnets) :
      contains(["REGIONAL_MANAGED_PROXY", "GLOBAL_MANAGED_PROXY"], subnet.purpose)
    ])
    error_message = "Each proxy subnet purpose must be either 'REGIONAL_MANAGED_PROXY' or 'GLOBAL_MANAGED_PROXY'."
  }

  # Validate that all subnets have a valid sequential numbering for cidr assignment
  validation {
    condition = alltrue([
      for key in keys(var.proxy_subnets) :
      can(regex(".*-[0-9]+$", key))
      ]) && (
      length(var.proxy_subnets) == 0 ? true :
      length([
        for i in range(1, length(var.proxy_subnets) + 1) :
        i if length([
          for key in keys(var.proxy_subnets) :
          key if can(regex(".*-${i}$", key))
        ]) == 1
      ]) == length(var.proxy_subnets)
    )
    error_message = "All subnet keys must end with '-number' and the numbers must be sequential starting from 1 (e.g., subnet-1, subnet-2, subnet-3). Each number from 1 to N must appear exactly once where N is the total number of subnets."
  }

  # Validate that BACKUP role is only allowed if there is at least one ACTIVE role in the same region
  validation {
    condition = alltrue([
      for subnet in var.proxy_subnets :
      subnet.role != "BACKUP" || anytrue([
        for other_subnet in var.proxy_subnets :
        other_subnet.region == subnet.region && other_subnet.role == "ACTIVE"
      ])
    ])
    error_message = "BACKUP role is only allowed if there is at least one ACTIVE role in the same region."
  }

  # Validate that each region can have at most one ACTIVE and one BACKUP subnet
  validation {
    condition = alltrue([
      for region in distinct([for subnet in var.proxy_subnets : subnet.region]) :
      length([for subnet in var.proxy_subnets : subnet if subnet.region == region && subnet.role == "ACTIVE"]) <= 1 &&
      length([for subnet in var.proxy_subnets : subnet if subnet.region == region && subnet.role == "BACKUP"]) <= 1
    ])
    error_message = "Each region can have at most one ACTIVE and one BACKUP subnet."
  }
}

variable "default_flow_logs_config" {
  type = object({
    enabled         = optional(bool, false)
    interval        = optional(string)
    sampling        = optional(string)
    metadata        = optional(string)
    filter          = optional(string)
    metadata_fields = optional(list(string), [])
  })
  description = "Default flow logs configuration for all subnets"
  default = {
    enabled         = false
    interval        = null
    sampling        = null
    metadata        = null
    filter          = null
    metadata_fields = []
  }
}

variable "enable_gke_secondary_ranges" {
  type        = bool
  description = "Whether to create secondary ranges for GKE pods and services"
  default     = true
}

variable "routing_mode" {
  type        = string
  description = "The network routing mode (REGIONAL or GLOBAL)"
  default     = "REGIONAL"
  validation {
    condition     = contains(["REGIONAL", "GLOBAL"], var.routing_mode)
    error_message = "The routing mode must be either REGIONAL or GLOBAL."
  }
}

variable "bgp_always_compare_med" {
  type        = bool
  description = "Whether to always compare the BGP Multi-Exit Discriminator (MED) attribute, which influences route selection when multiple paths exist."
  default     = false
}

variable "bgp_best_path_selection_mode" {
  type        = string
  description = "The BGP best path selection mode"
  default     = "STANDARD"
  validation {
    condition     = contains(["STANDARD", "LEGACY"], var.bgp_best_path_selection_mode)
    error_message = "The BGP best path selection mode must be either STANDARD or LEGACY."
  }
}

variable "bgp_inter_region_cost" {
  type        = string
  description = "The BGP inter-region cost"
  default     = "DEFAULT"
  validation {
    condition     = var.bgp_inter_region_cost == null || contains(["DEFAULT", "ADD_COST_TO_MED"], var.bgp_inter_region_cost)
    error_message = "The BGP inter-region cost must be either DEFAULT or ADD_COST_TO_MED."
  }
}

variable "mtu" {
  type        = number
  description = "The network MTU (must be a value between 1460 and 8896)"
  default     = 1460
  validation {
    condition     = var.mtu >= 1460 && var.mtu <= 8896
    error_message = "The MTU must be between 1460 and 8896."
  }
}

variable "delete_default_internet_gateway_routes" {
  type        = bool
  description = "Whether to delete the default internet gateway routes"
  default     = false
}

variable "encrypted_interconnect_router" {
  type        = bool
  description = "Whether to create a router dedicated to use with encrypted Interconnect Attachment"
  default     = false
}

#=======================
# Private Service Access
#=======================

variable "enable_private_service_access" {
  type        = bool
  description = "Whether to enable Private Service Access"
  default     = true
}

variable "psa_import_custom_routes" {
  type        = bool
  description = "Whether to import custom routes from the PSA peering into the VPC (required for Memorystore and other managed services to be routable)"
  default     = false
}

variable "psa_export_custom_routes" {
  type        = bool
  description = "Whether to export custom routes from the VPC to the PSA peering. Enable with caution if VPN/interconnect routes are present, as they will be visible to Google's managed network."
  default     = false
}

#===================
# CIDR Configuration
#===================

variable "base_cidr" {
  type        = string
  description = "The CIDR block for the VPC"
  validation {
    condition     = can(cidrhost(var.base_cidr, 0)) && endswith(var.base_cidr, "/16")
    error_message = "The base_cidr must be a valid CIDR block with a /16 notation."
  }
}

#====================
# Route Configuration
#====================

variable "additional_routes" {
  type = list(object({
    name                   = string
    description            = optional(string)
    tags                   = optional(string)
    destination_range      = string
    next_hop_internet      = optional(bool)
    next_hop_ip            = optional(string)
    next_hop_instance      = optional(string)
    next_hop_instance_zone = optional(string)
    next_hop_vpn_tunnel    = optional(string)
    next_hop_ilb           = optional(string)
    priority               = optional(number)
  }))
  description = "Additional routes to add to the VPC"
  default     = []
}

#===================
# Cloud Router & NAT
#===================

variable "enable_cloud_router" {
  type        = bool
  description = "Whether to create Cloud Router"
  default     = true
}

variable "enable_nat" {
  type        = bool
  description = "Whether to enable Cloud NAT on the Cloud Router"
  default     = true
}

variable "nat_configs" {
  type = object({
    name                               = optional(string)
    nat_ip_allocate_option             = optional(string, "AUTO_ONLY")
    source_subnetwork_ip_ranges_to_nat = optional(string, "ALL_SUBNETWORKS_ALL_IP_RANGES")
    min_ports_per_vm                   = optional(number)
    max_ports_per_vm                   = optional(number)

    # When set to true, Cloud NAT uses endpoint-independent mapping, which can improve compatibility for certain applications (e.g., SIP, FTP).
    enable_endpoint_independent_mapping = optional(bool, false)

    # When set to true, Cloud NAT dynamically allocates ports to VMs based on their usage, which can improve port utilization and reduce the risk of port exhaustion.
    enable_dynamic_port_allocation = optional(bool, true)

    # Only relevant when nat_ip_allocate_option is MANUAL_ONLY or AUTO_AND_MANUAL
    nat_ips       = optional(list(string), [])
    drain_nat_ips = optional(list(string), [])
    subnetworks = optional(list(object({
      name                     = string
      source_ip_ranges_to_nat  = list(string)
      secondary_ip_range_names = optional(list(string), [])
    })), [])

    # Optional Timeouts (in seconds)
    timeouts = optional(object({
      udp_idle_timeout_sec             = optional(number)
      icmp_idle_timeout_sec            = optional(number)
      tcp_established_idle_timeout_sec = optional(number)
      tcp_transitory_idle_timeout_sec  = optional(number)
      tcp_time_wait_timeout_sec        = optional(number)
    }), {})

    # Optional Logging
    log_config = optional(object({
      enable = optional(bool, false)
      filter = optional(string)
    }))

    # NAT Rules
    rules = optional(list(object({
      rule_number           = number
      description           = optional(string)
      match                 = string
      source_nat_active_ips = list(string)
    })), [])
  })
  description = "NAT configurations. Each configuration will create a separate NAT gateway."
  default     = {}

  validation {
    condition     = var.nat_configs == {} || contains(["AUTO_ONLY", "MANUAL_ONLY", "AUTO_AND_MANUAL"], try(var.nat_configs.nat_ip_allocate_option, "AUTO_ONLY"))
    error_message = "NAT IP allocation must be one of: AUTO_ONLY, MANUAL_ONLY, AUTO_AND_MANUAL."
  }

  validation {
    condition     = var.nat_configs == {} || contains(["ERRORS_ONLY", "TRANSLATIONS_ONLY", "ALL"], try(var.nat_configs.log_config.filter, "ERRORS_ONLY"))
    error_message = "NAT log filter must be one of: ERRORS_ONLY, TRANSLATIONS_ONLY, ALL."
  }

  validation {
    condition = var.nat_configs == {} || contains([
      "ALL_SUBNETWORKS_ALL_IP_RANGES",
      "ALL_SUBNETWORKS_ALL_PRIMARY_IP_RANGES",
      "LIST_OF_SUBNETWORKS"
    ], try(var.nat_configs.source_subnetwork_ip_ranges_to_nat, "ALL_SUBNETWORKS_ALL_IP_RANGES"))
    error_message = "source_subnetwork_ip_ranges_to_nat must be one of: ALL_SUBNETWORKS_ALL_IP_RANGES, ALL_SUBNETWORKS_ALL_PRIMARY_IP_RANGES, LIST_OF_SUBNETWORKS."
  }

  validation {
    condition = var.nat_configs == {} || alltrue([
      for rule in try(var.nat_configs.rules, []) :
      rule.rule_number >= 0 && rule.rule_number <= 65000
    ])
    error_message = "NAT rule numbers must be between 0 and 65000."
  }
}

variable "static_ips" {
  description = "Static IP addresses to create with full configuration options"
  type = list(object({
    name         = string
    description  = optional(string)
    address      = optional(string)
    address_type = optional(string, "EXTERNAL")
    network_tier = optional(string, "PREMIUM")
    subnetwork   = optional(string)
    network      = optional(string)
    labels       = optional(map(string))
    timeouts = optional(object({
      create = optional(string)
      delete = optional(string)
    }))
  }))
  default = []

  validation {
    condition = alltrue([
      for ip in var.static_ips :
      can(regex("^[a-z]([-a-z0-9]*[a-z0-9])?$", ip.name))
    ])
    error_message = "The name must be 1-63 characters long, and comply with RFC1035. Specifically, the name must be 1-63 characters long and match the regular expression [a-z]([-a-z0-9]*[a-z0-9])? which means the first character must be a lowercase letter, and all following characters must be a dash, lowercase letter, or digit, except the last character, which cannot be a dash."
  }

  validation {
    condition = alltrue([
      for ip in var.static_ips :
      contains(["EXTERNAL", "INTERNAL"], ip.address_type)
    ])
    error_message = "address_type must be either 'EXTERNAL' or 'INTERNAL'"
  }

  validation {
    condition = alltrue([
      for ip in var.static_ips :
      contains(["PREMIUM", "STANDARD"], ip.network_tier)
    ])
    error_message = "network_tier must be either 'PREMIUM' or 'STANDARD'"
  }
}

variable "bgp" {
  type = object({
    asn               = string
    advertise_mode    = optional(string, "CUSTOM")
    advertised_groups = optional(list(string))
    advertised_ip_ranges = optional(list(object({
      range       = string
      description = optional(string)
    })), [])
    keepalive_interval = optional(number)
  })
  description = "BGP information specific to this router"
  default     = null

  validation {
    condition     = var.bgp == null ? true : contains(["CUSTOM", "DEFAULT"], var.bgp.advertise_mode)
    error_message = "advertise_mode must be either 'CUSTOM' or 'DEFAULT'"
  }

  validation {
    condition = var.bgp == null ? true : alltrue([
      for group in coalesce(var.bgp.advertised_groups, []) :
      contains(["ALL_SUBNETS", "ALL_PEERING_VPC", "ALL_INTERNAL_VPC"], group)
    ])
    error_message = "advertised_groups can only contain 'ALL_SUBNETS', 'ALL_PEERING_VPC', or 'ALL_INTERNAL_VPC'"
  }
}

#=======================
# Firewall Configuration
#=======================

variable "firewall_rules" {
  type = object({
    ingress = optional(list(object({
      name                    = string
      description             = optional(string, null)
      disabled                = optional(bool, false)
      priority                = optional(number, null)
      destination_ranges      = optional(list(string), [])
      source_ranges           = optional(list(string), [])
      source_tags             = optional(list(string))
      source_service_accounts = optional(list(string))
      target_tags             = optional(list(string))
      target_service_accounts = optional(list(string))
      allow = optional(list(object({
        protocol = string
        ports    = optional(list(string))
      })), [])
      deny = optional(list(object({
        protocol = string
        ports    = optional(list(string))
      })), [])
      log_config = optional(object({
        metadata = string
      }))
    })), [])
    egress = optional(list(object({
      name                    = string
      description             = optional(string, null)
      disabled                = optional(bool, false)
      priority                = optional(number, null)
      destination_ranges      = optional(list(string), [])
      source_ranges           = optional(list(string), [])
      source_tags             = optional(list(string))
      source_service_accounts = optional(list(string))
      target_tags             = optional(list(string))
      target_service_accounts = optional(list(string))
      allow = optional(list(object({
        protocol = string
        ports    = optional(list(string))
      })), [])
      deny = optional(list(object({
        protocol = string
        ports    = optional(list(string))
      })), [])
      log_config = optional(object({
        metadata = string
      }))
    })), [])
  })
  description = "Firewall rules with full configuration options for both ingress and egress rules."
  default = {
    ingress = []
    egress  = []
  }
}
