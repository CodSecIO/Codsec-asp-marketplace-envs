locals {
  # if the provided name (or project) already contains the environment segment, just add the suffix.
  # Otherwise append the environment plus suffix.
  cluster_name_base   = coalesce(var.cluster_name, var.project)
  cluster_name        = can(regex("(^|-)${var.environment}(-|$)", local.cluster_name_base)) ? "${local.cluster_name_base}-gke" : "${local.cluster_name_base}-${var.environment}-gke"
  cluster_description = coalesce(var.description, "GKE cluster for ${var.project} ${var.environment}")
  # If regional is true, zones will be empty to let gke choose the zones, otherwise when creating a zonal cluster use the provided zone(s) or the first zone in the list
  zones = var.regional == true ? [] : coalesce(var.zones, [data.google_compute_zones.available.names[0]])
  # Split the available zones into a list
  available_zones = join(",", data.google_compute_zones.available.names)

  # Merge cluster resource labels with tags
  merged_tags = merge(
    var.cluster_resource_labels,
    var.tags,
    {
      project     = var.project
      environment = var.environment
    }
  )

  # Transform node_pools to list format for upstream module with priority merge from global_node_pools_config
  node_pools = [
    for pool_name, pool_config in var.node_pools :
    {
      name                         = pool_name
      machine_type                 = coalesce(pool_config.machine_type, var.global_node_pools_config.machine_type)
      min_count                    = try(coalesce(pool_config.min_count, var.global_node_pools_config.min_count), null)
      max_count                    = try(coalesce(pool_config.max_count, var.global_node_pools_config.max_count), null)
      total_min_count              = try(coalesce(pool_config.total_min_count, var.global_node_pools_config.total_min_count), null)
      total_max_count              = try(coalesce(pool_config.total_max_count, var.global_node_pools_config.total_max_count), null)
      location_policy              = coalesce(pool_config.location_policy, var.global_node_pools_config.location_policy)
      spot                         = coalesce(pool_config.spot, var.global_node_pools_config.spot)
      local_ssd_count              = coalesce(pool_config.local_ssd_count, var.global_node_pools_config.local_ssd_count)
      disk_size_gb                 = coalesce(pool_config.disk_size_gb, var.global_node_pools_config.disk_size_gb)
      disk_type                    = coalesce(pool_config.disk_type, var.global_node_pools_config.disk_type)
      image_type                   = coalesce(pool_config.image_type, var.global_node_pools_config.image_type)
      auto_repair                  = coalesce(pool_config.auto_repair, var.global_node_pools_config.auto_repair)
      auto_upgrade                 = coalesce(pool_config.auto_upgrade, var.global_node_pools_config.auto_upgrade)
      autoscaling                  = coalesce(pool_config.autoscaling, var.global_node_pools_config.autoscaling)
      strategy                     = coalesce(pool_config.strategy, var.global_node_pools_config.strategy)
      max_surge                    = coalesce(pool_config.max_surge, var.global_node_pools_config.max_surge)
      max_unavailable              = coalesce(pool_config.max_unavailable, var.global_node_pools_config.max_unavailable)
      max_pods_per_node            = try(coalesce(pool_config.max_pods_per_node, var.global_node_pools_config.max_pods_per_node), null)
      enable_nested_virtualization = coalesce(pool_config.enable_nested_virtualization, var.global_node_pools_config.enable_nested_virtualization)
      node_locations               = coalesce(pool_config.node_locations, var.global_node_pools_config.node_locations, local.available_zones)
    }
  ]

  # Merge global node pool config with cluster autoscaling for relevant fields
  merged_cluster_autoscaling = merge(
    var.cluster_autoscaling,
    {
      auto_repair                  = coalesce(var.cluster_autoscaling.auto_repair, var.global_node_pools_config.auto_repair)
      auto_upgrade                 = coalesce(var.cluster_autoscaling.auto_upgrade, var.global_node_pools_config.auto_upgrade)
      disk_size                    = coalesce(var.cluster_autoscaling.disk_size, var.global_node_pools_config.disk_size_gb)
      disk_type                    = coalesce(var.cluster_autoscaling.disk_type, var.global_node_pools_config.disk_type)
      image_type                   = coalesce(var.cluster_autoscaling.image_type, var.global_node_pools_config.image_type)
      strategy                     = coalesce(var.cluster_autoscaling.strategy, var.global_node_pools_config.strategy)
      max_surge                    = try(coalesce(var.cluster_autoscaling.max_surge, var.global_node_pools_config.max_surge), var.global_node_pools_config.max_surge)
      max_unavailable              = try(coalesce(var.cluster_autoscaling.max_unavailable, var.global_node_pools_config.max_unavailable), var.global_node_pools_config.max_unavailable)
      enable_secure_boot           = coalesce(var.cluster_autoscaling.enable_secure_boot, var.enable_secure_boot)
      enable_default_compute_class = coalesce(var.cluster_autoscaling.enable_default_compute_class, var.cluster_autoscaling.enabled)
    }
  )

  # Extract taints from node pools
  node_pools_taints = {
    for pool_name, pool_config in var.node_pools :
    pool_name => coalesce(pool_config.taints, [])
  }

  # Node pool OAuth scopes by pool name (defaults to cloud-platform)
  node_pools_oauth_scopes = {
    for pool_name, pool_config in var.node_pools :
    pool_name => length(coalesce(pool_config.oauth_scopes, [])) > 0 ? coalesce(pool_config.oauth_scopes, []) : [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
  }

  # Extract labels from node pools
  node_pools_labels = {
    for pool_name, pool_config in var.node_pools :
    pool_name => coalesce(pool_config.labels, var.global_node_pools_config.labels, {})
  }

  # Extract metadata from node pools
  node_pools_metadata = {
    for pool_name, pool_config in var.node_pools :
    pool_name => coalesce(pool_config.metadata, var.global_node_pools_config.metadata, {})
  }

  filestore_node_tag = "filestore"

  node_pools_tags = {
    for pool_name, pool_config in var.node_pools :
    pool_name => (
      var.filestore_csi_driver
      ? distinct(concat(
        coalesce(pool_config.tags, var.global_node_pools_config.tags, []),
        [local.filestore_node_tag]
      ))
      : coalesce(pool_config.tags, var.global_node_pools_config.tags, [])
    )
  }

  # Extract resource labels from node pools
  node_pools_resource_labels = {
    for pool_name, pool_config in var.node_pools :
    pool_name => coalesce(pool_config.resource_labels, var.global_node_pools_config.resource_labels, {})
  }

  # Extract resource manager tags from node pools
  node_pools_resource_manager_tags = {
    for pool_name, pool_config in var.node_pools :
    pool_name => coalesce(pool_config.resource_manager_tags, var.global_node_pools_config.resource_manager_tags, {})
  }

  # Extract linux node configs sysctls from node pools
  node_pools_linux_node_configs_sysctls = {
    for pool_name, pool_config in var.node_pools :
    pool_name => try(pool_config.linux_node_configs_sysctls.sysctls, {})
  }

  # Extract cgroup mode from linux node configs
  node_pools_cgroup_mode = {
    for pool_name, pool_config in var.node_pools :
    pool_name => try(pool_config.linux_node_configs_sysctls.cgroup_mode, "")
  }

  # Extract hugepage size 1g from linux node configs
  node_pools_hugepage_size_1g = {
    for pool_name, pool_config in var.node_pools :
    pool_name => try(pool_config.linux_node_configs_sysctls.hugepage_size_1g, "")
  }

  # Extract hugepage size 2m from linux node configs
  node_pools_hugepage_size_2m = {
    for pool_name, pool_config in var.node_pools :
    pool_name => try(pool_config.linux_node_configs_sysctls.hugepage_size_2m, "")
  }

  # Network Tags
  default_network_tags = [
    var.project,
    "gke-node",
    "allow-health-check",
    "firewall-allow"
  ]

  network_tags = distinct(concat(var.network_tags, local.default_network_tags))

  # Default Filestore StorageClasses
  basic_hdd_storageclass = var.filestore_basic_hdd_storageclass ? [{
    name        = "standard-filestore"
    provisioner = "filestore.csi.storage.gke.io"
    parameters = {
      tier    = "BASIC_HDD"
      network = var.networking_config.network
    }
    allow_volume_expansion = true
    volume_binding_mode    = "WaitForFirstConsumer"
  }] : []

  basic_ssd_storageclass = var.filestore_basic_ssd_storageclass ? [{
    name        = "ssd-filestore"
    provisioner = "filestore.csi.storage.gke.io"
    parameters = {
      tier    = "BASIC_SSD"
      network = var.networking_config.network
    }
    allow_volume_expansion = true
    volume_binding_mode    = "WaitForFirstConsumer"
  }] : []

  storageclasses = concat(local.basic_hdd_storageclass, local.basic_ssd_storageclass, var.additional_storageclasses)

  # Google Groups for RBAC - smart logic to handle both full format and domain-only format
  # GKE requires the group to be named exactly: gke-security-groups@<domain>
  # If authenticator_security_group is provided:
  #   - If it starts with "gke-security-groups@", use as-is
  #   - Otherwise, add the prefix
  # Else: null

  # Check if authenticator_security_group already has the prefix
  security_group_has_prefix = var.authenticator_security_group != null && can(regex("^gke-security-groups@", var.authenticator_security_group))

  # Build the final security group name
  authenticator_security_group = var.authenticator_security_group != null ? (
    local.security_group_has_prefix ? var.authenticator_security_group : "gke-security-groups@${var.authenticator_security_group}"
  ) : null

  #=================================================================
  # ComputeClass Configuration - Merge with global_node_pools_config
  #=================================================================

  # Transform compute_classes map to list format for Helm chart with defaults from global_node_pools_config
  merged_compute_classes = [
    for cc_name, cc_config in var.compute_classes : {
      name               = cc_name
      description        = cc_config.description
      when_unsatisfiable = cc_config.when_unsatisfiable

      # Node Pool Auto Creation
      node_pool_auto_creation = cc_config.node_pool_auto_creation

      # Autoscaling Policy
      autoscaling_policy = cc_config.autoscaling_policy

      # Active Migration
      active_migration = cc_config.active_migration

      # Node Pool Config - merge with global defaults
      node_pool_config = cc_config.node_pool_config != null ? {
        image_type             = coalesce(cc_config.node_pool_config.image_type, lower(var.global_node_pools_config.image_type))
        service_account        = cc_config.node_pool_config.service_account
        confidential_node_type = cc_config.node_pool_config.confidential_node_type
        workload_type          = cc_config.node_pool_config.workload_type
        node_labels            = coalesce(cc_config.node_pool_config.node_labels, var.global_node_pools_config.labels, {})
        taints                 = cc_config.node_pool_config.taints
      } : null

      # Node Pool Group
      node_pool_group = cc_config.node_pool_group

      # Priority Defaults
      priority_defaults = cc_config.priority_defaults

      # Priorities - merge storage defaults from global config
      priorities = [
        for priority in cc_config.priorities : {
          nodepools                        = priority.nodepools
          machine_family                   = priority.machine_family
          machine_type                     = priority.machine_type
          min_cores                        = priority.min_cores
          min_memory_gb                    = priority.min_memory_gb
          max_pods_per_node                = priority.max_pods_per_node
          max_run_duration_seconds         = priority.max_run_duration_seconds
          capacity_check_wait_time_seconds = priority.capacity_check_wait_time_seconds
          spot                             = coalesce(priority.spot, var.global_node_pools_config.spot)
          location                         = priority.location
          gpu                              = priority.gpu
          tpu                              = priority.tpu
          reservations                     = priority.reservations
          flex_start                       = priority.flex_start
          node_system_config               = priority.node_system_config

          # Storage - merge with global defaults
          storage = priority.storage != null ? {
            boot_disk_type       = coalesce(priority.storage.boot_disk_type, var.global_node_pools_config.disk_type)
            boot_disk_size       = coalesce(priority.storage.boot_disk_size, var.global_node_pools_config.disk_size_gb)
            boot_disk_kms_key    = priority.storage.boot_disk_kms_key
            local_ssd_count      = coalesce(priority.storage.local_ssd_count, var.global_node_pools_config.local_ssd_count)
            secondary_boot_disks = priority.storage.secondary_boot_disks
          } : null
        }
      ]
    }
  ]
}
