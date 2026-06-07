#================
#   General
#================

variable "enable_apis" {
  description = "Whether to enable required GCP APIs"
  type        = bool
  default     = true
}

variable "project_id" {
  description = "The GCP project ID where resources will be created"
  type        = string
}

variable "project" {
  description = "The name of the project"
  type        = string
}

variable "environment" {
  description = "The environment name"
  type        = string
}

variable "region" {
  description = "The GCP region where resources will be created"
  type        = string
  default     = null
}

variable "cluster_dns_endpoint" {
  description = "Whether to use the DNS endpoint for the Kubernetes provider"
  type        = bool
  default     = false
}

######################################################################################################################
# General Cluster Configuration
######################################################################################################################

variable "cluster_name" {
  description = "The name of the GKE cluster"
  type        = string
  default     = null
}

variable "regional" {
  description = "Whether to create a regional or zonal cluster"
  type        = bool
  default     = true
}

variable "zones" {
  description = "The list of zones where the cluster will be deployed, must be specified when regional is false"
  type        = list(string)
  default     = []

  # Vendored copy: cross-variable validation removed - it referenced
  # var.regional (Terraform >= 1.9 only; Marketplace runs 1.5.7). It also
  # rejected the empty-zones case that locals.tf handles by picking the
  # first available zone.
}

variable "kubernetes_version" {
  description = "The Kubernetes version for the GKE cluster"
  type        = string
  default     = null
}

variable "release_channel" {
  description = "The release channel of this cluster"
  type        = string
  default     = "STABLE"

  validation {
    condition     = var.release_channel == null ? true : contains(["STABLE", "REGULAR", "RAPID"], var.release_channel)
    error_message = "release_channel must be one of: STABLE, REGULAR, RAPID or null."
  }
}

variable "enable_identity_service" {
  description = "Enable the Identity Service component, which allows customers to use external identity providers with the K8S API."
  type        = bool
  default     = false
}

variable "identity_namespace" {
  description = "The workload pool to attach all Kubernetes service accounts to. (Default value of `enabled` automatically sets project-based pool `[project_id].svc.id.goog`)"
  type        = string
  default     = "enabled"
}

variable "cluster_resource_labels" {
  description = "The GCE resource labels (a map of key/value pairs) to be applied to the cluster"
  type        = map(string)
  default     = {}
}

variable "registry_project_ids" {
  description = "Projects holding Google Container Registries. If empty, we use the cluster project. If a service account is created and the `grant_registry_access` variable is set to `true`, the `storage.objectViewer` and `artifactregsitry.reader` roles are assigned on these projects."
  type        = list(string)
  default     = []
}

variable "grant_registry_access" {
  description = "Grants created cluster-specific service account storage.objectViewer and artifactregistry.reader roles."
  type        = bool
  default     = true
}

variable "enable_gcfs" {
  description = "Enable image streaming on cluster level"
  type        = bool
  default     = true
}

variable "remove_default_node_pool" {
  description = "Whether to remove the default node pool created by GKE. Set to true to disable the 'default-pool'."
  type        = bool
  default     = true
}

variable "default_max_pods_per_node" {
  description = "The default maximum number of pods per node for the GKE cluster"
  type        = number
  default     = 110
}

variable "tags" {
  description = "A map of tags to assign to resources"
  type        = map(string)
  default     = {}
}

variable "description" {
  description = "Optional description for the GKE cluster"
  type        = string
  default     = ""
}

variable "deletion_protection" {
  description = "Whether or not to allow Terraform to destroy the cluster"
  type        = bool
  default     = false
}

######################################################################################################################
# Network Configuration
######################################################################################################################
variable "networking_config" {
  description = "Network Configuration for the GKE cluster"
  type = object({
    network                     = string                 # The VPC network name where the GKE cluster will be deployed
    subnetwork                  = string                 # The subnet name where the GKE cluster nodes will be deployed
    private_endpoint_subnetwork = optional(string, null) # The subnet name where the GKE cluster private endpoint will be deployed

    # IP Range Configuration
    ip_range_pods            = string
    ip_range_services        = string
    additional_ip_range_pods = optional(list(string), [])
  })
}

variable "master_authorized_networks" {
  description = "List of master authorized networks. If none are provided, disallow external access (except the cluster node IPs, which GKE automatically whitelists)."
  type = list(object({
    cidr_block   = string
    display_name = string
  }))
  default = []
}

variable "network_tags" {
  description = "A list of network tags to apply to the GKE cluster"
  type        = list(string)
  default     = []
}

variable "enable_private_endpoint" {
  description = "Whether to enable private endpoint for the GKE cluster"
  type        = bool
  default     = false
}

variable "enable_private_nodes" {
  description = "Whether to enable private nodes for the GKE cluster"
  type        = bool
  default     = true
}

variable "master_ipv4_cidr_block" {
  description = "The IP range for the master nodes"
  type        = string
  default     = null

  validation {
    condition = (
      var.master_ipv4_cidr_block == null ||
      (can(cidrhost(var.master_ipv4_cidr_block, 0)) &&
      can(regex("/(28|27|26|25|24)$", var.master_ipv4_cidr_block)))
    )
    error_message = "master_ipv4_cidr_block must be a valid CIDR block with subnet mask between /24 and /28 (e.g., '172.16.0.0/28'). Google recommends /28 for most use cases."
  }
}

variable "enable_l4_ilb_subsetting" {
  description = "Enable L4 ILB Subsetting on the cluster (Groups VM endpoints efficiently for internal NLBs using NEGs (Network Endpoint Groups))"
  type        = bool
  default     = true
}

variable "dns_allow_external_traffic" {
  description = "Whether to allow external traffic to the cluster"
  type        = bool
  default     = true
}

variable "cluster_dns_domain" {
  description = "The domain for the cluster"
  type        = string
  default     = null
}

variable "cluster_dns_provider" {
  description = "The DNS provider for the cluster"
  type        = string
  default     = "PLATFORM_DEFAULT"

  validation {
    condition     = var.cluster_dns_provider == null ? true : contains(["PROVIDER_UNSPECIFIED", "PLATFORM_DEFAULT", "CLOUD_DNS"], var.cluster_dns_provider)
    error_message = "cluster_dns_provider must be one of: PROVIDER_UNSPECIFIED, PLATFORM_DEFAULT, CLOUD_DNS."
  }
}

variable "cluster_dns_scope" {
  description = "The DNS scope for the cluster"
  type        = string
  default     = null

  validation {
    condition     = var.cluster_dns_scope == null ? true : contains(["DNS_SCOPE_UNSPECIFIED", "CLUSTER_SCOPE", "VPC_SCOPE"], var.cluster_dns_scope)
    error_message = "cluster_dns_scope must be one of: DNS_SCOPE_UNSPECIFIED, CLUSTER_SCOPE, VPC_SCOPE."
  }
}

variable "additive_vpc_scope_dns_domain" {
  description = "The DNS domain for the cluster"
  type        = string
  default     = null
}

variable "datapath_provider" {
  description = "The datapath provider for the cluster"
  type        = string
  default     = "ADVANCED_DATAPATH"

  validation {
    condition     = contains(["ADVANCED_DATAPATH", "DATAPATH_PROVIDER_UNSPECIFIED"], var.datapath_provider)
    error_message = "datapath_provider must be either ADVANCED_DATAPATH or DATAPATH_PROVIDER_UNSPECIFIED."
  }
}

######################################################################################################################
# Node Pools Configuration
######################################################################################################################

variable "global_node_pools_config" {
  description = "Global node pool defaults configuration - these values will be used as defaults for all node pools unless overridden. NOTE: Either this variable's machine_type or at least one node pool's machine_type must be specified."
  type = object({
    machine_type                 = optional(string)
    spot                         = optional(bool, false)
    node_locations               = optional(string)
    min_count                    = optional(number)
    max_count                    = optional(number)
    total_min_count              = optional(number)
    total_max_count              = optional(number)
    location_policy              = optional(string, "ANY")
    auto_repair                  = optional(bool, true)
    auto_upgrade                 = optional(bool, true)
    autoscaling                  = optional(bool, true)
    strategy                     = optional(string, "SURGE")
    max_surge                    = optional(number)
    max_unavailable              = optional(number)
    max_pods_per_node            = optional(number)
    enable_nested_virtualization = optional(bool, false)

    # Disk Configuration
    local_ssd_count = optional(number, 0)
    disk_size_gb    = optional(number, 100)
    disk_type       = optional(string, "pd-standard")

    # Image Configuration
    image_type = optional(string, "COS_CONTAINERD")

    # Service Account Configuration
    oauth_scopes = optional(list(string), [])

    # Labels and Tags
    labels                = optional(map(string), {})
    tags                  = optional(list(string), [])
    metadata              = optional(map(string), {})
    resource_labels       = optional(map(string), {})
    resource_manager_tags = optional(map(string), {})
  })
  default = {}
}

variable "node_pools" {
  description = "Node pool configurations. NOTE: If specified, node pools must have machine_type set, or global_node_pools_config.machine_type must be specified."
  type = map(object({
    machine_type                 = optional(string)
    spot                         = optional(bool)
    node_locations               = optional(string)
    min_count                    = optional(number)
    max_count                    = optional(number)
    total_min_count              = optional(number)
    total_max_count              = optional(number)
    location_policy              = optional(string)
    auto_repair                  = optional(bool)
    auto_upgrade                 = optional(bool)
    autoscaling                  = optional(bool)
    strategy                     = optional(string, "SURGE")
    max_surge                    = optional(number)
    max_unavailable              = optional(number)
    max_pods_per_node            = optional(number)
    enable_nested_virtualization = optional(bool)

    # Disk Configuration
    local_ssd_count = optional(number)
    disk_size_gb    = optional(number)
    disk_type       = optional(string)

    # Image Configuration
    image_type = optional(string)

    # Service Account Configuration
    oauth_scopes = optional(list(string))

    # Labels and Tags
    labels                = optional(map(string))
    tags                  = optional(list(string))
    metadata              = optional(map(string))
    resource_labels       = optional(map(string))
    resource_manager_tags = optional(map(string))

    # Node Affinity
    node_affinity = optional(object({
      key      = string
      operator = string
      values   = list(string)
    }), null)

    # Taints
    taints = optional(list(object({
      key    = string
      value  = string
      effect = string
    })), [])

    # Linux Node Configuration (includes sysctls and cgroup_mode)
    linux_node_configs_sysctls = optional(object({
      sysctls          = optional(map(string), {})
      cgroup_mode      = optional(string, "")
      hugepage_size_1g = optional(string, "")
      hugepage_size_2m = optional(string, "")
    }))
  }))
  default = {}

  validation {
    condition = alltrue([
      for pool_name, pool_config in var.node_pools :
      pool_config.strategy == null || contains(["SURGE", "BLUE_GREEN", "SHORT_LIVED"], pool_config.strategy)
    ])
    error_message = "strategy must be one of: SURGE, BLUE_GREEN, SHORT_LIVED for all node pools."
  }

  # Vendored copy: cross-variable validation removed (referenced
  # var.global_node_pools_config; Terraform >= 1.9 only, Marketplace runs
  # 1.5.7). The root module always sets machine_type on every pool.
}

####################################################
# Cluster Autoscaling - NAP (Node Auto-Provisioning)
####################################################
variable "cluster_autoscaling" {
  description = "Cluster autoscaling configuration for the GKE cluster"
  type = object({
    enabled             = optional(bool, false)
    autoscaling_profile = optional(string, "BALANCED")
    min_cpu_cores       = optional(number, 0)
    max_cpu_cores       = optional(number, 100)
    min_memory_gb       = optional(number, 0)
    max_memory_gb       = optional(number, 640)
    gpu_resources = optional(list(object({
      resource_type = string
      minimum       = number
      maximum       = number
    })), [])
    auto_repair                  = optional(bool, true)
    auto_upgrade                 = optional(bool, true)
    disk_size                    = optional(number, 100)
    disk_type                    = optional(string, "pd-standard")
    image_type                   = optional(string, "COS_CONTAINERD")
    strategy                     = optional(string)
    max_surge                    = optional(number)
    max_unavailable              = optional(number)
    node_pool_soak_duration      = optional(string)
    batch_soak_duration          = optional(string)
    batch_percentage             = optional(number)
    batch_node_count             = optional(number)
    enable_secure_boot           = optional(bool, false)
    enable_integrity_monitoring  = optional(bool, true)
    enable_default_compute_class = optional(bool)
  })
  default = {}

  validation {
    condition     = (var.cluster_autoscaling.autoscaling_profile == null && var.cluster_autoscaling.enabled == false) ? true : contains(["BALANCED", "OPTIMIZE_UTILIZATION"], var.cluster_autoscaling.autoscaling_profile)
    error_message = "autoscaling_profile must be one of: BALANCED, OPTIMIZE_UTILIZATION."
  }

  validation {
    condition     = var.cluster_autoscaling.enabled == false || (var.cluster_autoscaling.enabled == true && var.cluster_autoscaling.max_cpu_cores > 0 && var.cluster_autoscaling.max_memory_gb > 0)
    error_message = "cluster_autoscaling.max_cpu_cores and cluster_autoscaling.max_memory_gb must be greater than 0 when cluster_autoscaling.enabled is true."
  }
}



######################################################################################################################
# ComputeClass Configuration (NAP Custom Compute Classes)
######################################################################################################################

variable "compute_classes" {
  description = "Map of ComputeClass configurations to create. ComputeClasses define autoscaling profiles for GKE nodes with NAP. Use nodeSelector 'cloud.google.com/compute-class: <name>' to schedule workloads."
  type = map(object({
    description        = optional(string)
    when_unsatisfiable = optional(string, "DoNotScaleUp") # DoNotScaleUp or ScaleUpAnyway

    # Node Pool Auto Creation (requires NAP enabled on cluster)
    node_pool_auto_creation = optional(object({
      enabled = optional(bool, true)
    }), { enabled = true })

    # Autoscaling Policy
    autoscaling_policy = optional(object({
      consolidation_delay_minutes = optional(number, 10) # 1-1440, default 10 min
      consolidation_threshold     = optional(number, 50) # 0-100 (percentage), default 50%
      gpu_consolidation_threshold = optional(number)     # 0-100 (percentage)
    }), {})

    # Active Migration Settings
    active_migration = optional(object({
      optimize_rule_priority             = optional(bool, false)
      ensure_all_daemon_set_pods_running = optional(bool)
    }))

    # Node Pool Configuration
    node_pool_config = optional(object({
      image_type             = optional(string) # cos_containerd or ubuntu_containerd
      service_account        = optional(string)
      confidential_node_type = optional(string) # SEV, SEV_SNP, TDX
      workload_type          = optional(string) # HIGH_AVAILABILITY or HIGH_THROUGHPUT
      node_labels            = optional(map(string))
      taints = optional(list(object({
        key    = string
        value  = string
        effect = string # NoSchedule, PreferNoSchedule, NoExecute
      })))
    }))

    # Node Pool Group (for multi-host TPU/GPU)
    node_pool_group = optional(object({
      name = string
    }))

    # Priority Defaults (applied to all priorities unless overridden)
    priority_defaults = optional(object({
      location = optional(object({
        zones = list(string)
      }))
      node_system_config = optional(object({
        kubelet_config = optional(object({
          cpu_manager_policy              = optional(string)
          cpu_cfs_quota                   = optional(bool)
          cpu_cfs_quota_period            = optional(string)
          pod_pids_limit                  = optional(number)
          image_gc_high_threshold_percent = optional(number)
          image_gc_low_threshold_percent  = optional(number)
        }))
        linux_node_config = optional(object({
          sysctls = optional(map(string))
          hugepage_config = optional(object({
            hugepage_size_1g = optional(number)
            hugepage_size_2m = optional(number)
          }))
        }))
      }))
    }))

    # Priorities - the core configuration (required)
    priorities = list(object({
      # Reference existing node pools (mutually exclusive with other fields)
      nodepools = optional(list(string))

      # Machine specification (mutually exclusive: machine_family OR machine_type)
      machine_family = optional(string) # e.g., e2, n2, c2
      machine_type   = optional(string) # e.g., e2-standard-4

      # Resource requirements
      min_cores     = optional(number)
      min_memory_gb = optional(number)

      # Node constraints
      max_pods_per_node                = optional(number) # 8-256
      max_run_duration_seconds         = optional(number)
      capacity_check_wait_time_seconds = optional(number) # 1-86400

      # Spot VMs
      spot = optional(bool)

      # Location preferences
      location = optional(object({
        zones = list(string)
      }))

      # GPU Configuration
      gpu = optional(object({
        type           = optional(string) # e.g., nvidia-tesla-t4
        count          = optional(number)
        driver_version = optional(string) # default or latest
      }))

      # TPU Configuration
      tpu = optional(object({
        type     = optional(string)
        count    = optional(number)
        topology = optional(string)
      }))

      # Storage Configuration
      storage = optional(object({
        boot_disk_type    = optional(string) # pd-balanced, pd-standard, pd-ssd, hyperdisk-balanced
        boot_disk_size    = optional(number) # GB, minimum 10
        boot_disk_kms_key = optional(string)
        local_ssd_count   = optional(number)
        secondary_boot_disks = optional(list(object({
          disk_image_name = string
          project         = optional(string)
          mode            = optional(string) # MODE_UNSPECIFIED, CONTAINER_IMAGE_CACHE
        })))
      }))

      # Reservations
      reservations = optional(object({
        affinity = string # Specific, AnyBestEffort, None
        specific = optional(list(object({
          name    = string
          project = optional(string)
          reservation_block = optional(object({
            name = string
            reservation_sub_block = optional(object({
              name = string
            }))
          }))
        })))
      }))

      # Flex Start (dynamic scheduling)
      flex_start = optional(object({
        enabled = optional(bool, false)
        node_recycling = optional(object({
          lead_time_seconds = number # 1-604800
        }))
      }))

      # Node System Config per priority
      node_system_config = optional(object({
        kubelet_config = optional(object({
          cpu_manager_policy              = optional(string)
          cpu_cfs_quota                   = optional(bool)
          cpu_cfs_quota_period            = optional(string)
          pod_pids_limit                  = optional(number)
          image_gc_high_threshold_percent = optional(number)
          image_gc_low_threshold_percent  = optional(number)
        }))
        linux_node_config = optional(object({
          sysctls = optional(map(string))
          hugepage_config = optional(object({
            hugepage_size_1g = optional(number)
            hugepage_size_2m = optional(number)
          }))
        }))
      }))
    }))
  }))
  default = {}

  validation {
    condition = alltrue([
      for name, cc in var.compute_classes :
      contains(["DoNotScaleUp", "ScaleUpAnyway"], cc.when_unsatisfiable)
    ])
    error_message = "when_unsatisfiable must be 'DoNotScaleUp' or 'ScaleUpAnyway'."
  }

  validation {
    condition = alltrue([
      for name, cc in var.compute_classes :
      cc.autoscaling_policy == null || (
        (cc.autoscaling_policy.consolidation_delay_minutes == null || (cc.autoscaling_policy.consolidation_delay_minutes >= 1 && cc.autoscaling_policy.consolidation_delay_minutes <= 1440)) &&
        (cc.autoscaling_policy.consolidation_threshold == null || (cc.autoscaling_policy.consolidation_threshold >= 0 && cc.autoscaling_policy.consolidation_threshold <= 100)) &&
        (cc.autoscaling_policy.gpu_consolidation_threshold == null || (cc.autoscaling_policy.gpu_consolidation_threshold >= 0 && cc.autoscaling_policy.gpu_consolidation_threshold <= 100))
      )
    ])
    error_message = "autoscaling_policy values must be within valid ranges: consolidation_delay_minutes (1-1440), consolidation_threshold (0-100), gpu_consolidation_threshold (0-100)."
  }

  validation {
    condition = alltrue([
      for name, cc in var.compute_classes :
      cc.node_pool_config == null || cc.node_pool_config.image_type == null || contains(["cos_containerd", "ubuntu_containerd"], cc.node_pool_config.image_type)
    ])
    error_message = "node_pool_config.image_type must be 'cos_containerd' or 'ubuntu_containerd'."
  }

  validation {
    condition = alltrue([
      for name, cc in var.compute_classes :
      cc.node_pool_config == null || cc.node_pool_config.confidential_node_type == null || contains(["SEV", "SEV_SNP", "TDX"], cc.node_pool_config.confidential_node_type)
    ])
    error_message = "node_pool_config.confidential_node_type must be 'SEV', 'SEV_SNP', or 'TDX'."
  }

  validation {
    condition = alltrue([
      for name, cc in var.compute_classes :
      cc.node_pool_config == null || cc.node_pool_config.workload_type == null || contains(["HIGH_AVAILABILITY", "HIGH_THROUGHPUT"], cc.node_pool_config.workload_type)
    ])
    error_message = "node_pool_config.workload_type must be 'HIGH_AVAILABILITY' or 'HIGH_THROUGHPUT'."
  }

  validation {
    condition = alltrue([
      for name, cc in var.compute_classes :
      length(cc.priorities) > 0
    ])
    error_message = "Each ComputeClass must have at least one priority defined."
  }

  validation {
    condition = alltrue([
      for name, cc in var.compute_classes :
      alltrue([
        for p in cc.priorities :
        !(p.machine_family != null && p.machine_type != null)
      ])
    ])
    error_message = "machine_family and machine_type cannot be specified together in the same priority."
  }

  validation {
    condition = alltrue([
      for name, cc in var.compute_classes :
      alltrue([
        for p in cc.priorities :
        !(p.machine_type != null && (p.min_cores != null || p.min_memory_gb != null))
      ])
    ])
    error_message = "machine_type cannot be specified together with min_cores or min_memory_gb in the same priority."
  }
}


######################################################################################################################
# Monitoring and Observability Configuration
######################################################################################################################
variable "enable_resource_consumption_export" {
  description = "Whether to enable resource consumption metering on this cluster. When enabled, a table will be created in the resource export BigQuery dataset to store resource consumption data."
  type        = bool
  default     = true
}

variable "resource_usage_export_dataset_id" {
  description = "The ID of the BigQuery dataset where resource consumption data will be stored."
  type        = string
  default     = ""
}

variable "enable_cost_allocation" {
  description = "Enables Cost Allocation Feature and the cluster name and namespace of your GKE workloads appear in the labels field of the billing export to BigQuery"
  type        = bool
  default     = true
}

variable "monitoring_enable_managed_prometheus" {
  description = "Configuration for Managed Service for Prometheus. Whether or not the managed collection is enabled."
  type        = bool
  default     = false
}

variable "monitoring_enable_observability_metrics" {
  description = "Whether or not the advanced datapath metrics are enabled."
  type        = bool
  default     = false
}

variable "monitoring_enable_observability_relay" {
  description = "Enable observability relay for the GKE cluster"
  type        = bool
  default     = false
}

variable "monitoring_service" {
  description = "The monitoring service that the cluster should write metrics to. Available options include monitoring.googleapis.com, monitoring.googleapis.com/kubernetes (beta), and none"
  type        = string
  default     = "none"

  validation {
    condition     = contains(["monitoring.googleapis.com", "monitoring.googleapis.com/kubernetes", "none"], var.monitoring_service)
    error_message = "monitoring_service must be one of: 'monitoring.googleapis.com', 'monitoring.googleapis.com/kubernetes', or 'none'."
  }
}

variable "monitoring_enabled_components" {
  description = "List of services to monitor: SYSTEM_COMPONENTS, APISERVER, SCHEDULER, CONTROLLER_MANAGER, STORAGE, HPA, POD, DAEMONSET, DEPLOYMENT, STATEFULSET, KUBELET, CADVISOR, DCGM, and JOBSET."
  type        = list(string)
  default     = []

  validation {
    condition = var.monitoring_enabled_components == null || length(var.monitoring_enabled_components) == 0 || alltrue([
      for component in var.monitoring_enabled_components :
      contains(["SYSTEM_COMPONENTS", "APISERVER", "SCHEDULER", "CONTROLLER_MANAGER", "STORAGE", "HPA", "POD", "DAEMONSET", "DEPLOYMENT", "STATEFULSET", "KUBELET", "CADVISOR", "DCGM", "JOBSET"], component)
    ])
    error_message = "Invalid monitoring_enabled_components. Allowed values are: SYSTEM_COMPONENTS, APISERVER, SCHEDULER, CONTROLLER_MANAGER, STORAGE, HPA, POD, DAEMONSET, DEPLOYMENT, STATEFULSET, KUBELET, CADVISOR, DCGM, and JOBSET."
  }
}

variable "enable_network_egress_export" {
  description = "Whether to enable network egress metering for this cluster. If enabled, a daemonset will be created in the cluster to meter network egress traffic."
  type        = bool
  default     = false
}

variable "logging_enabled_components" {
  description = "List of services to monitor: SYSTEM_COMPONENTS, APISERVER, CONTROLLER_MANAGER, KCP_CONNECTION, KCP_SSHD, KCP_HPA, SCHEDULER, and WORKLOADS. Empty list is default GKE configuration."
  type        = list(string)
  default     = []

  validation {
    condition = var.logging_enabled_components == null || length(var.logging_enabled_components) == 0 || alltrue([
      for component in var.logging_enabled_components :
      contains(["SYSTEM_COMPONENTS", "APISERVER", "CONTROLLER_MANAGER", "KCP_CONNECTION", "KCP_SSHD", "KCP_HPA", "SCHEDULER", "WORKLOADS"], component)
    ])
    error_message = "Invalid logging_enabled_components. Allowed values are: SYSTEM_COMPONENTS, APISERVER, CONTROLLER_MANAGER, KCP_CONNECTION, KCP_SSHD, KCP_HPA, SCHEDULER, and WORKLOADS."
  }
}

variable "logging_service" {
  description = "The logging service that the cluster should write logs to. Available options include logging.googleapis.com, logging.googleapis.com/kubernetes (beta), and none"
  type        = string
  default     = "none"

  validation {
    condition     = contains(["logging.googleapis.com", "logging.googleapis.com/kubernetes", "none"], var.logging_service)
    error_message = "logging_service must be one of: 'logging.googleapis.com', 'logging.googleapis.com/kubernetes', or 'none'."
  }
}

variable "logging_variant" {
  description = "The logging variant for the GKE cluster"
  type        = string
  default     = "DEFAULT"

  validation {
    condition     = contains(["DEFAULT", "MAX_THROUGHPUT"], var.logging_variant)
    error_message = "logging_variant must be one of: DEFAULT, MAX_THROUGHPUT."
  }
}

######################################################################################################################
# Addons Configuration
######################################################################################################################

variable "enable_secret_manager_addon" {
  description = "Enable the Secret Manager add-on for this cluster"
  type        = bool
  default     = false
}

variable "http_load_balancing" {
  description = "Enable HTTP load balancer addon"
  type        = bool
  default     = true
}

variable "ray_operator_config" {
  description = "The Ray Operator Addon configuration for this cluster."
  type = object({
    enabled            = optional(bool, false)
    logging_enabled    = optional(bool, false)
    monitoring_enabled = optional(bool, false)
  })
  default = {
    enabled            = false
    logging_enabled    = false
    monitoring_enabled = false
  }
}

variable "horizontal_pod_autoscaling" {
  description = "Enable horizontal pod autoscaling addon"
  type        = bool
  default     = true
}

variable "hpa_profile" {
  description = "Enable the Horizontal Pod Autoscaling profile for this cluster. Values are \"NONE\" and \"PERFORMANCE\"."
  type        = string
  default     = ""

  validation {
    condition     = var.hpa_profile == "" ? true : contains(["NONE", "PERFORMANCE"], var.hpa_profile)
    error_message = "hpa_profile must be one of: NONE, PERFORMANCE."
  }
}

variable "enable_vertical_pod_autoscaling" {
  description = "Vertical Pod Autoscaling automatically adjusts the resources of pods controlled by it"
  type        = bool
  default     = false
}

variable "persistent_disk_csi_driver" {
  description = "Whether this cluster should enable the Persistent Disk CSI Driver."
  type        = bool
  default     = true
}

variable "gce_pd_csi_driver" {
  description = "Whether this cluster should enable the Google Compute Engine Persistent Disk Container Storage Interface (CSI) Driver."
  type        = bool
  default     = true
}

variable "filestore_csi_driver" {
  description = "The status of the Filestore CSI driver addon, which allows the usage of filestore instance as volumes"
  type        = bool
  default     = false
}

variable "gcs_fuse_csi_driver" {
  description = "Whether GCE FUSE CSI driver is enabled for this cluster."
  type        = bool
  default     = false
}

variable "parallelstore_csi_driver" {
  description = "Whether the Parallelstore CSI driver Addon is enabled for this cluster."
  type        = bool
  default     = false
}

variable "gke_backup_agent_config" {
  description = "Whether Backup for GKE agent is enabled for this cluster."
  type        = bool
  default     = false
}

variable "dns_cache" {
  description = "The status of the NodeLocal DNSCache addon."
  type        = bool
  default     = false
}

variable "gateway_api_channel" {
  description = "The Gateway API channel for this cluster. Gateway API is used for advanced traffic management and load balancing."
  type        = string
  default     = "CHANNEL_DISABLED"

  validation {
    condition     = var.gateway_api_channel == null || contains(["CHANNEL_STANDARD", "CHANNEL_DISABLED"], var.gateway_api_channel)
    error_message = "gateway_api_channel must be one of: CHANNEL_STANDARD, CHANNEL_DISABLED, or null."
  }
}

variable "anonymous_authentication_config_mode" {
  description = "Allows users to restrict or enable anonymous access to the cluster. LIMITED restricts anonymous access, ENABLED allows it."
  type        = string
  default     = "LIMITED"

  validation {
    condition     = contains(["ENABLED", "LIMITED"], var.anonymous_authentication_config_mode)
    error_message = "anonymous_authentication_config_mode must be one of: ENABLED, LIMITED."
  }
}

######################################################################################################################
# Maintenance Configuration
######################################################################################################################
variable "maintenance_start_time" {
  description = "The start time of the maintenance window in HH:MM format"
  type        = string
  default     = "03:00"
}

variable "maintenance_end_time" {
  description = "The end time of the maintenance window in HH:MM format"
  type        = string
  default     = "06:00"
}

variable "maintenance_recurrence" {
  description = "The recurrence of the maintenance window in RFC5545 format"
  type        = string
  default     = "FREQ=WEEKLY;BYDAY=SA,SU"

  validation {
    condition     = var.maintenance_recurrence == null ? true : can(regex("^FREQ=(DAILY|WEEKLY|MONTHLY|YEARLY);", var.maintenance_recurrence))
    error_message = "maintenance_recurrence must be in RFC5545 format (e.g., FREQ=WEEKLY;BYDAY=SA,SU)."
  }
}

variable "maintenance_exclusions" {
  description = "List of maintenance exclusions for the GKE cluster"
  type = list(object({
    name            = string
    start_time      = string
    end_time        = string
    exclusion_scope = string
  }))
  default = []

  validation {
    condition     = length(var.maintenance_exclusions) <= 3
    error_message = "A cluster can have up to three maintenance exclusions."
  }
}

######################################################################################################################
# Security Configuration
######################################################################################################################
variable "enable_binary_authorization" {
  description = "Enable Binary Authorization for this cluster"
  type        = bool
  default     = false
}

variable "enable_confidential_nodes" {
  description = "Enable Confidential Nodes for this cluster"
  type        = bool
  default     = false
}

variable "enable_secure_boot" {
  description = "Enable Secure Boot for this cluster"
  type        = bool
  default     = false
}

variable "database_encryption" {
  description = "Database encryption configuration"
  type = list(object({
    state    = optional(string, "ENCRYPTED")
    key_name = string
  }))
  default = []
}

variable "enable_shielded_nodes" {
  description = "Enable Shielded Nodes for this cluster"
  type        = bool
  default     = true
}

variable "enable_mesh_certificates" {
  description = "Enable Mesh Certificates for this cluster"
  type        = bool
  default     = false
}

variable "node_metadata" {
  description = "Node metadata configuration"
  type        = string
  default     = "GKE_METADATA"
}

######################################################################################################################
# Google Groups for RBAC Configuration
######################################################################################################################
# Enables Google Groups integration with Kubernetes RBAC by configuring the "gke-security-groups@<domain>" group that bridges Google Workspace identity to Kubernetes RBAC.
######################################################################################################################
variable "authenticator_security_group" {
  description = "RBAC security group name for Google Groups integration - accepts full format (gke-security-groups@raysecurity.io) or domain only (raysecurity.io), prefix added automatically if needed."
  type        = string
  default     = null
}

#########################
# Firewall Configuration
#########################
variable "add_cluster_firewall_rules" {
  description = "Whether to add cluster firewall rules"
  type        = bool
  default     = true
}

variable "add_master_webhook_firewall_rules" {
  description = "Whether to add master webhook firewall rules"
  type        = bool
  default     = true
}

variable "firewall_inbound_ports" {
  description = "List of inbound ports for firewall rules"
  type        = list(string)
  default     = ["8443", "9443", "15017"]
}

variable "firewall_priority" {
  description = "Priority for firewall rules"
  type        = number
  default     = 1000
}

variable "add_shadow_firewall_rules" {
  description = "Whether to add shadow firewall rules for auditing denied traffic"
  type        = bool
  default     = false
}

variable "shadow_firewall_rules_log_config" {
  description = "Log configuration for shadow firewall rules"
  type = object({
    metadata = optional(string, "INCLUDE_ALL_METADATA")
  })
  default = {
    metadata = "INCLUDE_ALL_METADATA"
  }
}

variable "shadow_firewall_rules_priority" {
  description = "Priority for shadow firewall rules"
  type        = number
  default     = 999
}

#########################
# Storage Configuration
#########################

variable "filestore_basic_hdd_storageclass" {
  description = "Whether to create a basic HDD storageclass for the Filestore CSI driver"
  type        = bool
  default     = false
}

variable "filestore_basic_ssd_storageclass" {
  description = "Whether to create a basic SSD storageclass for the Filestore CSI driver"
  type        = bool
  default     = false
}

variable "additional_storageclasses" {
  description = "List of additional Kubernetes StorageClasses to create."
  type = list(object({
    name                   = string
    provisioner            = string
    parameters             = map(string)
    allow_volume_expansion = bool
    volume_binding_mode    = string
  }))
  default = []
}