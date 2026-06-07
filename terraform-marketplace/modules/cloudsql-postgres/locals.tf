# ============================================================================
# NAMING AND COMPUTED VALUES
# ============================================================================

locals {
  prefix = "${var.project}-${var.environment}"

  name_to_check = coalesce(var.name, var.project)
  name          = can(regex("(^|-)${var.environment}(-|$)", local.name_to_check)) ? "${local.name_to_check}-psql" : "${local.name_to_check}-${var.environment}-psql"

  # Convert database flags map to list(object) expected by upstream module
  database_flags_list = [for k, v in var.database_flags : {
    name  = k
    value = tostring(v)
  }]

  secret_id = "${local.name}-root-password"

  read_replicas = [
    for replica_name, replica_config in var.read_replicas : {
      name          = startswith(replica_name, local.prefix) ? replica_name : "${local.prefix}-${replica_name}"
      name_override = null

      tier              = coalesce(replica_config.tier, var.tier)
      availability_type = coalesce(replica_config.availability_type, var.availability_type)
      zone              = coalesce(replica_config.zone, var.secondary_zone)

      disk_type             = coalesce(try(replica_config.disk.type, null), var.disk.type)
      disk_size             = tostring(coalesce(try(replica_config.disk.size, null), var.disk.size))
      disk_autoresize       = coalesce(try(replica_config.disk.autoresize, null), var.disk.autoresize)
      disk_autoresize_limit = coalesce(try(replica_config.disk.autoresize_limit, null), var.disk.autoresize_limit)

      user_labels    = replica_config.labels != null ? merge(var.labels, replica_config.labels) : var.labels
      database_flags = replica_config.database_flags != null ? [for k, v in replica_config.database_flags : { name = k, value = tostring(v) }] : local.database_flags_list

      insights_config = {
        query_plans_per_minute  = coalesce(try(replica_config.insights_config.query_plans_per_minute, null), try(var.insights_config.query_plans_per_minute, null))
        query_string_length     = coalesce(try(replica_config.insights_config.query_string_length, null), try(var.insights_config.query_string_length, null))
        record_application_tags = coalesce(try(replica_config.insights_config.record_application_tags, null), try(var.insights_config.record_application_tags, null))
        record_client_address   = coalesce(try(replica_config.insights_config.record_client_address, null), try(var.insights_config.record_client_address, null))
      }

      # IP configuration - inherit from main if not specified
      ip_configuration = {
        authorized_networks                           = coalesce(try(replica_config.ip_configuration.authorized_networks, null), var.ip_configuration.authorized_networks)
        ipv4_enabled                                  = coalesce(try(replica_config.ip_configuration.ipv4_enabled, null), var.ip_configuration.ipv4_enabled)
        private_network                               = coalesce(try(replica_config.ip_configuration.private_network, null), var.ip_configuration.private_network)
        ssl_mode                                      = coalesce(try(replica_config.ip_configuration.ssl_mode, null), var.ip_configuration.ssl_mode)
        allocated_ip_range                            = coalesce(try(replica_config.ip_configuration.allocated_ip_range, null), var.ip_configuration.allocated_ip_range)
        enable_private_path_for_google_cloud_services = coalesce(try(replica_config.ip_configuration.enable_private_path_for_google_cloud_services, null), var.ip_configuration.enable_private_path_for_google_cloud_services)
        psc_enabled                                   = coalesce(try(replica_config.ip_configuration.psc_enabled, null), var.ip_configuration.psc_enabled)
        psc_allowed_consumer_projects                 = coalesce(try(replica_config.ip_configuration.psc_allowed_consumer_projects, null), var.ip_configuration.psc_allowed_consumer_projects)
      }

      # Replica-specific settings
      encryption_key_name = coalesce(replica_config.encryption_key_name, var.encryption_key_name)
    }
  ]

  # ============================================================================
  # CLOUD SQL AUTH PROXY CONFIGURATION
  # ============================================================================

  # Transform auth_proxies map - defaults are handled by variable definition
  auth_proxy_instances = [
    for proxy_name, proxy_config in var.auth_proxies : {
      name = "${var.environment}-ap-${proxy_name}"
      zone = coalesce(proxy_config.zone, "${var.region}-b")

      # VM configuration - defaults handled by variable
      vm_machine_type    = proxy_config.vm.machine_type
      vm_network         = coalesce(proxy_config.vm.network, var.ip_configuration.private_network)
      vm_subnetwork      = proxy_config.vm.subnetwork
      vm_allow_public_ip = proxy_config.vm.allow_public_ip

      # Container configuration - defaults handled by variable
      container_image      = proxy_config.container.image
      container_args       = proxy_config.container.args
      container_command    = proxy_config.container.command
      container_cos_family = proxy_config.container.cos_image_family

      # Firewall configuration - defaults handled by variable
      firewall_source_ranges = proxy_config.firewall.source_ranges
      firewall_network       = coalesce(proxy_config.firewall.network, var.ip_configuration.private_network)

      # Labels with system labels
      labels = merge(var.labels, proxy_config.labels, {
        database = local.name
        proxy    = proxy_name
      })
    }
  ]

  # Password for each additional user (either provided explicitly or generated by the upstream module).
  # The upstream module exposes these via the `additional_users` output, which is a list of objects
  # with the shape `{ name = <username>, password = <password> }`.
  user_passwords_map = {
    for u in module.postgresql.additional_users :
    u.name => u.password
  }

  # Convert map inputs to lists compatible with upstream module
  additional_databases_list = [
    for db_name, db_cfg in var.additional_databases : {
      name      = db_name
      charset   = try(db_cfg.charset, null)
      collation = try(db_cfg.collation, null)
    }
  ]

  additional_users_list = [
    for user in var.additional_users : {
      name            = user
      password        = null
      random_password = true
    }
  ]
}
