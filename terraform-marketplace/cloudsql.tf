# Managed PostgreSQL via our vendored cloudsql-postgres module (wraps
# terraform-google-modules/sql-db//modules/postgresql). Private IP only,
# reached from the cluster over the VPC. deletion_protection defaults to true:
# deleting the Infrastructure Manager deployment otherwise destroys the
# database and its data.

module "cloudsql" {
  source = "./modules/cloudsql-postgres"

  project_id  = var.project_id
  project     = var.name_prefix
  environment = var.environment
  region      = var.region

  database_version  = "POSTGRES_16"
  tier              = var.db_tier
  availability_type = var.db_availability_type

  disk = {
    size             = var.db_disk_size
    type             = "PD_SSD"
    autoresize       = true
    autoresize_limit = var.db_disk_size * 5
  }

  backup_configuration = {
    enabled                        = true
    start_time                     = "02:00"
    point_in_time_recovery_enabled = true
    retained_backups               = 7
  }

  ip_configuration = {
    ipv4_enabled                                  = false
    private_network                               = local.network_id
    psc_enabled                                   = false
    enable_private_path_for_google_cloud_services = true
  }

  additional_databases = {
    (var.db_name) = {}
  }
  additional_users = [var.db_user]

  deletion_protection = var.db_deletion_protection
  enable_apis         = false

  # PSA must exist before a private-IP instance is created; module.vpc owns it
  # when create_network = true (empty list otherwise, which is a no-op).
  depends_on = [module.project_services, module.vpc]
}
