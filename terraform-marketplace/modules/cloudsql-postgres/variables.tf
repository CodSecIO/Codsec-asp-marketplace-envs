# ============================================================================
# REQUIRED VARIABLES
# ============================================================================

variable "enable_apis" {
  description = "Enable required GCP APIs for this module"
  type        = bool
  default     = true
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "project" {
  description = "Project name for naming conventions"
  type        = string
}

variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region for the PostgreSQL instance"
  type        = string
}

variable "zone" {
  description = "GCP zone for the PostgreSQL instance primary zone"
  type        = string
  default     = null
}

variable "secondary_zone" {
  description = "Secondary zone for the PostgreSQL instance replication/failover"
  type        = string
  default     = null
}

# ============================================================================
# DATABASE CONFIGURATION
# ============================================================================
variable "enable_default_db" {
  description = "Enable default database"
  type        = bool
  default     = false
}

variable "database_version" {
  description = "PostgreSQL version (e.g., POSTGRES_15, POSTGRES_14, POSTGRES_13)"
  type        = string
  validation {
    condition     = can(regex("^POSTGRES_", var.database_version))
    error_message = "Database version must be a PostgreSQL version (e.g., POSTGRES_15)."
  }
}

variable "tier" {
  description = "Machine tier for the PostgreSQL instance (e.g., db-f1-micro, db-n1-standard-1)"
  type        = string
}

variable "edition" {
  description = "PostgreSQL edition (e.g., ENTERPRISE_PLUS, ENTERPRISE)"
  type        = string
  default     = "ENTERPRISE"

  validation {
    condition     = contains(["ENTERPRISE_PLUS", "ENTERPRISE"], var.edition)
    error_message = "Edition must be ENTERPRISE_PLUS or ENTERPRISE."
  }
}

variable "insights_config" {
  description = "The insights_config settings for the database."
  type = object({
    query_plans_per_minute  = optional(number, 5)
    query_string_length     = optional(number, 1024)
    record_application_tags = optional(bool, false)
    record_client_address   = optional(bool, false)
  })
  default = {}
}

variable "additional_databases" {
  description = "Map of extra PostgreSQL databases to create. Key = database name."
  type = map(object({
    charset   = optional(string, "UTF8")
    collation = optional(string, "en_US.UTF8")
  }))
  default = {}
}

variable "additional_users" {
  description = "List of PostgreSQL user names to create. Random passwords are generated and stored in Secret Manager."
  type        = list(string)
  default     = []
}

variable "connector_enforcement" {
  description = "Connector enforcement mode"
  type        = bool
  default     = false

  # Vendored copy: cross-variable validation removed - it referenced
  # var.read_replicas, which requires Terraform >= 1.9, and Marketplace /
  # Infrastructure Manager run 1.5.7. Cloud SQL itself rejects the invalid
  # combination at apply time.
}

# ============================================================================
# ROOT USER CONFIGURATION
# ============================================================================

variable "root_user" {
  description = "Root user (postgres superuser) configuration"
  type = object({
    enabled  = optional(bool, true)
    password = optional(string, null)
  })
  sensitive = true
  default   = {}
}

# ============================================================================
# NETWORKING CONFIGURATION
# ============================================================================

variable "ip_configuration" {
  description = "The ip configuration for the Cloud SQL instances."
  type = object({
    authorized_networks                           = optional(list(map(string)), [])
    ipv4_enabled                                  = optional(bool, false)
    private_network                               = optional(string, null)
    ssl_mode                                      = optional(string, "ALLOW_UNENCRYPTED_AND_ENCRYPTED")
    allocated_ip_range                            = optional(string)
    enable_private_path_for_google_cloud_services = optional(bool, true)
    psc_enabled                                   = optional(bool, true)
    psc_allowed_consumer_projects                 = optional(list(string), [])
  })
  default = {}
}

# ============================================================================
# INSTANCE CONFIGURATION
# ============================================================================

variable "availability_type" {
  description = "Availability type (ZONAL or REGIONAL)"
  type        = string
  default     = "REGIONAL"
  validation {
    condition     = contains(["ZONAL", "REGIONAL"], var.availability_type)
    error_message = "Availability type must be ZONAL or REGIONAL."
  }
}

variable "disk" {
  description = "Disk configuration for the Cloud SQL instance"
  type = object({
    size             = optional(number, 100)
    type             = optional(string, "PD_SSD")
    autoresize       = optional(bool, true)
    autoresize_limit = optional(number, 200)
  })
  validation {
    condition = alltrue([
      contains(["PD_SSD", "PD_HDD"], var.disk.type),
      var.disk.size > 0,
      var.disk.autoresize_limit >= var.disk.size
    ])
    error_message = "Invalid disk configuration. Type must be PD_SSD or PD_HDD, size must be positive, and autoresize_limit must be >= size."
  }
  default = {}
}

variable "backup_configuration" {
  description = "Backup configuration"
  type = object({
    enabled                        = optional(bool, true)
    start_time                     = optional(string, "02:00")
    location                       = optional(string)
    point_in_time_recovery_enabled = optional(bool, true)
    transaction_log_retention_days = optional(number, 2)
    retained_backups               = optional(number, 3)
    retention_unit                 = optional(string, "COUNT")
  })
  default = {}
}

variable "maintenance_window" {
  description = "Maintenance window configuration"
  type = object({
    day  = optional(number, 7) # Sunday
    hour = optional(number, 3) # 3 AM
  })
  default = {}
}

variable "database_flags" {
  description = "Map of additional PostgreSQL database flags to configure (e.g., { max_connections = \"500\" })"
  type        = map(string)
  default     = {}
}

variable "deletion_protection" {
  description = "Enable deletion protection"
  type        = bool
  default     = false
}

# ============================================================================
# OPTIONAL CONFIGURATION
# ============================================================================

variable "name" {
  description = "Custom instance name (auto-generated if not specified)"
  type        = string
  default     = null
}

variable "labels" {
  description = "Additional tags to apply to resources"
  type        = map(string)
  default     = {}
}

variable "enable_random_password_special" {
  description = "Enable random password special characters"
  type        = bool
  default     = true
}

variable "master_instance_name" {
  description = "The name of the master instance if this is a failover replica"
  type        = string
  default     = null
}

variable "encryption_key_name" {
  description = "The name of the encryption key to use for the instance"
  type        = string
  default     = null
}

# ============================================================================
# READ REPLICAS CONFIGURATION
# ============================================================================

variable "read_replicas" {
  description = "Map of read replicas to create. Values not specified will inherit from the main instance configuration."
  type = map(object({
    # Basic configuration - inherits from main if not specified
    tier              = optional(string)
    availability_type = optional(string)
    zone              = optional(string)

    # Disk configuration - structured like main instance
    disk = optional(object({
      size             = optional(number)
      type             = optional(string)
      autoresize       = optional(bool)
      autoresize_limit = optional(number)
    }))

    # Optional overrides
    database_flags = optional(map(string))
    insights_config = optional(object({
      query_plans_per_minute  = optional(number)
      query_string_length     = optional(number)
      record_application_tags = optional(bool)
      record_client_address   = optional(bool)
    }))
    ip_configuration = optional(object({
      authorized_networks                           = optional(list(map(string)))
      ipv4_enabled                                  = optional(bool)
      private_network                               = optional(string)
      ssl_mode                                      = optional(string)
      allocated_ip_range                            = optional(string)
      enable_private_path_for_google_cloud_services = optional(bool)
      psc_enabled                                   = optional(bool)
      psc_allowed_consumer_projects                 = optional(list(string))
    }))

    encryption_key_name = optional(string)
    labels              = optional(map(string))
  }))
  default = {}
}

# ============================================================================
# SECRET MANAGER CONFIGURATION
# ============================================================================

variable "store_password_in_secret_manager" {
  description = "Whether to automatically store the root password in Google Secret Manager"
  type        = bool
  default     = true
}

# ============================================================================
# CLOUD SQL AUTH PROXY CONFIGURATION
# ============================================================================

variable "auth_proxies" {
  description = "Map of Cloud SQL Auth Proxy instances to create (only used when connector_enforcement = true). Values not specified will inherit from defaults."
  type = map(object({
    # Basic configuration
    zone = optional(string, null) # Will default to "${var.region}-a"

    # VM Configuration
    vm = optional(object({
      machine_type    = optional(string, "e2-standard-2")
      network         = optional(string, null) # Will default to ip_configuration.private_network
      subnetwork      = optional(string, null)
      allow_public_ip = optional(bool, false)
      }), {
      machine_type    = "e2-standard-2"
      network         = null
      subnetwork      = null
      allow_public_ip = false
    })

    # Container Configuration
    container = optional(object({
      image            = optional(string, "gcr.io/cloud-sql-connectors/cloud-sql-proxy:latest")
      args             = optional(list(string), [])
      command          = optional(list(string), [])
      cos_image_family = optional(string, "stable")
      }), {
      image            = "gcr.io/cloud-sql-connectors/cloud-sql-proxy:latest"
      args             = []
      command          = []
      cos_image_family = "stable"
    })

    # Firewall Configuration
    firewall = optional(object({
      source_ranges = optional(list(string), ["10.0.0.0/8"])
      network       = optional(string, null) # Will default to ip_configuration.private_network
      }), {
      source_ranges = ["10.0.0.0/8"]
      network       = null
    })

    # Labels
    labels = optional(map(string), {})
  }))
  default = {}
}
