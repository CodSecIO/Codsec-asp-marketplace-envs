locals {
  name = var.name_prefix
}

# --------------------------------------------------------------------------
# Networking: VPC + subnet + Private Service Access (for Cloud SQL private IP)
# --------------------------------------------------------------------------
resource "google_compute_network" "vpc" {
  project                 = var.project_id
  name                    = "${local.name}-vpc"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "subnet" {
  project       = var.project_id
  name          = "${local.name}-subnet"
  ip_cidr_range = "10.20.0.0/20"
  region        = var.region
  network       = google_compute_network.vpc.id

  secondary_ip_range {
    range_name    = "pods"
    ip_cidr_range = "10.40.0.0/14"
  }
  secondary_ip_range {
    range_name    = "services"
    ip_cidr_range = "10.36.0.0/20"
  }
}

resource "google_compute_global_address" "private_ip" {
  project       = var.project_id
  name          = "${local.name}-psa-range"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = google_compute_network.vpc.id
}

resource "google_service_networking_connection" "psa" {
  network                 = google_compute_network.vpc.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip.name]
}

# --------------------------------------------------------------------------
# GKE Autopilot (app runs here; reaches Cloud SQL over the VPC private IP)
# --------------------------------------------------------------------------
resource "google_container_cluster" "gke" {
  project          = var.project_id
  name             = "${local.name}-gke"
  location         = var.region
  enable_autopilot = true

  network    = google_compute_network.vpc.id
  subnetwork = google_compute_subnetwork.subnet.id

  ip_allocation_policy {
    cluster_secondary_range_name  = "pods"
    services_secondary_range_name = "services"
  }

  deletion_protection = var.gke_deletion_protection
}

# --------------------------------------------------------------------------
# Managed PostgreSQL (Cloud SQL) - durable, automated backups, private IP
# --------------------------------------------------------------------------
resource "random_password" "db" {
  length  = 32
  special = false
}

resource "google_sql_database_instance" "pg" {
  project          = var.project_id
  name             = "${local.name}-pg"
  region           = var.region
  database_version = "POSTGRES_16"

  depends_on = [google_service_networking_connection.psa]

  settings {
    tier              = var.db_tier
    availability_type = "ZONAL"
    disk_autoresize   = true

    ip_configuration {
      ipv4_enabled    = false
      private_network = google_compute_network.vpc.id
    }

    backup_configuration {
      enabled                        = true
      point_in_time_recovery_enabled = true
    }
  }

  deletion_protection = var.db_deletion_protection
}

resource "google_sql_database" "app" {
  project  = var.project_id
  name     = var.db_name
  instance = google_sql_database_instance.pg.name
}

resource "google_sql_user" "app" {
  project  = var.project_id
  name     = var.db_user
  instance = google_sql_database_instance.pg.name
  password = random_password.db.result
}

# --------------------------------------------------------------------------
# App secrets generated at deploy time
# --------------------------------------------------------------------------
resource "random_password" "jwt" {
  length  = 48
  special = false
}

# Static external IP for the ingress (so DNS can be pointed at a stable address).
resource "google_compute_global_address" "ingress" {
  project = var.project_id
  name    = "${local.name}-ingress-ip"
}

# --------------------------------------------------------------------------
# Helm + Kubernetes providers, authenticated against the created GKE cluster
# --------------------------------------------------------------------------
data "google_client_config" "default" {}

provider "kubernetes" {
  host                   = "https://${google_container_cluster.gke.endpoint}"
  token                  = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(google_container_cluster.gke.master_auth[0].cluster_ca_certificate)
}

provider "helm" {
  kubernetes {
    host                   = "https://${google_container_cluster.gke.endpoint}"
    token                  = data.google_client_config.default.access_token
    cluster_ca_certificate = base64decode(google_container_cluster.gke.master_auth[0].cluster_ca_certificate)
  }
}

# --------------------------------------------------------------------------
# Deploy the app (backend + frontend + in-cluster Redis) via Helm.
# Postgres connection points at the managed Cloud SQL private IP.
# --------------------------------------------------------------------------
resource "helm_release" "asp" {
  name             = local.name
  namespace        = local.name
  create_namespace = true

  chart   = var.chart_oci_ref
  version = var.chart_version

  set {
    name  = "domain"
    value = var.domain
  }
  set {
    name  = "backend.image.repo"
    value = var.backend_image
  }
  set {
    name  = "backend.image.tag"
    value = var.image_tag
  }
  set {
    name  = "frontend.image.repo"
    value = var.frontend_image
  }
  set {
    name  = "frontend.image.tag"
    value = var.image_tag
  }
  set {
    name  = "postgres.host"
    value = google_sql_database_instance.pg.private_ip_address
  }
  set {
    name  = "postgres.database"
    value = var.db_name
  }
  set {
    name  = "postgres.user"
    value = var.db_user
  }
  set_sensitive {
    name  = "postgres.password"
    value = random_password.db.result
  }
  set_sensitive {
    name  = "jwtSecret"
    value = random_password.jwt.result
  }

  depends_on = [
    google_container_cluster.gke,
    google_sql_user.app,
  ]
}
