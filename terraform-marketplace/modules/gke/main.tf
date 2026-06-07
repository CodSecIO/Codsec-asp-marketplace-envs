#==============================================
# GCP API Enablement
#==============================================

resource "google_project_service" "apis" {
  for_each = var.enable_apis ? toset([
    "container.googleapis.com",
  ]) : toset([])

  project                    = var.project_id
  service                    = each.value
  disable_on_destroy         = false
  disable_dependent_services = false
}

#==============================================
# GKE Cluster
#==============================================

module "gke" {
  source  = "terraform-google-modules/kubernetes-engine/google//modules/private-cluster"
  version = "43.0.0"

  depends_on = [google_project_service.apis]

  # Core Configuration
  project_id         = var.project_id
  name               = local.cluster_name
  description        = local.cluster_description
  region             = var.region
  regional           = var.regional
  zones              = local.zones
  kubernetes_version = var.kubernetes_version
  release_channel    = var.release_channel

  # General Configuration
  enable_identity_service  = var.enable_identity_service
  registry_project_ids     = var.registry_project_ids
  remove_default_node_pool = var.remove_default_node_pool
  identity_namespace       = var.identity_namespace
  grant_registry_access    = var.grant_registry_access

  enable_gcfs               = var.enable_gcfs # GKE Feature: Image Streaming, Used to reduce image pull times
  default_max_pods_per_node = var.default_max_pods_per_node
  deletion_protection       = var.deletion_protection

  # Network Configuration
  network                  = var.networking_config.network
  subnetwork               = var.networking_config.subnetwork
  ip_range_pods            = var.networking_config.ip_range_pods
  ip_range_services        = var.networking_config.ip_range_services
  additional_ip_range_pods = var.networking_config.additional_ip_range_pods

  master_authorized_networks = var.master_authorized_networks
  enable_private_endpoint    = var.enable_private_endpoint
  enable_private_nodes       = var.enable_private_nodes
  master_ipv4_cidr_block     = var.master_ipv4_cidr_block
  network_tags               = local.network_tags
  datapath_provider          = var.datapath_provider

  # Cluster DNS Configuration
  enable_l4_ilb_subsetting      = var.enable_l4_ilb_subsetting # Groups VM endpoints efficiently for internal NLBs using NEGs (Network Endpoint Groups)
  dns_allow_external_traffic    = var.dns_allow_external_traffic
  cluster_dns_domain            = var.cluster_dns_domain
  cluster_dns_provider          = var.cluster_dns_provider
  cluster_dns_scope             = var.cluster_dns_scope
  additive_vpc_scope_dns_domain = var.additive_vpc_scope_dns_domain

  # Node Pool Configuration
  cluster_autoscaling                   = local.merged_cluster_autoscaling
  node_pools                            = local.node_pools
  node_pools_oauth_scopes               = local.node_pools_oauth_scopes
  node_pools_labels                     = local.node_pools_labels
  node_pools_metadata                   = local.node_pools_metadata
  node_pools_tags                       = local.node_pools_tags
  node_pools_taints                     = local.node_pools_taints
  node_pools_resource_labels            = local.node_pools_resource_labels
  node_pools_resource_manager_tags      = local.node_pools_resource_manager_tags
  node_pools_linux_node_configs_sysctls = local.node_pools_linux_node_configs_sysctls
  node_pools_cgroup_mode                = local.node_pools_cgroup_mode
  node_pools_hugepage_size_1g           = local.node_pools_hugepage_size_1g
  node_pools_hugepage_size_2m           = local.node_pools_hugepage_size_2m

  # Addons Configuration
  http_load_balancing             = var.http_load_balancing
  horizontal_pod_autoscaling      = var.horizontal_pod_autoscaling
  hpa_profile                     = var.hpa_profile
  enable_vertical_pod_autoscaling = var.enable_vertical_pod_autoscaling
  enable_secret_manager_addon     = var.enable_secret_manager_addon
  dns_cache                       = var.dns_cache # Enables NodeLocal DNSCache GKE Addon that runs in addition to kube-dns
  gateway_api_channel             = var.gateway_api_channel
  ray_operator_config             = var.ray_operator_config
  filestore_csi_driver            = var.filestore_csi_driver
  gcs_fuse_csi_driver             = var.gcs_fuse_csi_driver
  gke_backup_agent_config         = var.gke_backup_agent_config

  # Monitoring and Observability Configuration
  monitoring_enable_managed_prometheus    = var.monitoring_enable_managed_prometheus
  monitoring_enable_observability_metrics = var.monitoring_enable_observability_metrics
  monitoring_enable_observability_relay   = var.monitoring_enable_observability_relay
  monitoring_enabled_components           = var.monitoring_enabled_components
  monitoring_service                      = var.monitoring_service

  enable_cost_allocation             = var.enable_cost_allocation
  enable_resource_consumption_export = var.enable_resource_consumption_export
  resource_usage_export_dataset_id   = var.resource_usage_export_dataset_id
  enable_network_egress_export       = var.enable_network_egress_export

  # Logging Configuration
  logging_enabled_components = var.logging_enabled_components
  logging_service            = var.logging_service
  logging_variant            = var.logging_variant

  # Security Configuration
  enable_shielded_nodes                = var.enable_shielded_nodes
  enable_binary_authorization          = var.enable_binary_authorization
  database_encryption                  = var.database_encryption
  enable_confidential_nodes            = var.enable_confidential_nodes
  enable_mesh_certificates             = var.enable_mesh_certificates
  anonymous_authentication_config_mode = var.anonymous_authentication_config_mode

  # Google Groups for RBAC
  authenticator_security_group = local.authenticator_security_group

  # Firewall Rules
  add_cluster_firewall_rules        = var.add_cluster_firewall_rules
  add_master_webhook_firewall_rules = var.add_master_webhook_firewall_rules
  add_shadow_firewall_rules         = var.add_shadow_firewall_rules
  shadow_firewall_rules_log_config  = var.shadow_firewall_rules_log_config
  shadow_firewall_rules_priority    = var.shadow_firewall_rules_priority
  firewall_inbound_ports            = var.firewall_inbound_ports
  firewall_priority                 = var.firewall_priority

  # Maintenance Configuration
  maintenance_start_time = var.maintenance_start_time
  maintenance_exclusions = var.maintenance_exclusions
  maintenance_recurrence = var.maintenance_recurrence

  # Resource Labels
  cluster_resource_labels = local.merged_tags
}

resource "google_compute_firewall" "allow_filestore_nfs" {
  count      = var.filestore_csi_driver ? 1 : 0
  depends_on = [module.gke]
  name       = "gke-nodes-allow-filestore-nfs"
  network    = var.networking_config.network

  allow {
    protocol = "tcp"
    ports    = ["111", "2046", "2049", "2050", "4045"]
  }
  allow {
    protocol = "udp"
    ports    = ["111", "2046", "2049", "2050", "4045"]
  }

  source_tags = [local.filestore_node_tag] # Tag on GKE nodes
  target_tags = ["filestore-instance"]     # Tag on Filestore instance

  direction   = "INGRESS"
  priority    = 1000
  description = "Allow NFS and file locking traffic from GKE nodes to Filestore"
}
