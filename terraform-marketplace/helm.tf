# Deploys the ASP chart (frontend + backend + in-cluster Redis) onto the
# selected cluster. Postgres is the managed Cloud SQL instance from
# cloudsql.tf - the chart is rendered with postgres.bundled=false so its
# bundled demo Postgres stays off and DATABASE_URL points at Cloud SQL.

provider "helm" {
  kubernetes {
    host                   = local.cluster_endpoint
    token                  = data.google_client_config.default.access_token
    cluster_ca_certificate = local.cluster_ca
  }
}

# Default kubernetes provider: inherited by kubernetes_* resources inside the
# upstream kubernetes-engine module (e.g. the optional ip-masq ConfigMap).
provider "kubernetes" {
  host                   = local.cluster_endpoint
  token                  = data.google_client_config.default.access_token
  cluster_ca_certificate = local.cluster_ca
}

locals {
  helm_release_name = var.helm_release_name != "" ? var.helm_release_name : "asp"
}

resource "helm_release" "asp" {
  name             = local.helm_release_name
  namespace        = var.namespace
  create_namespace = true

  repository = var.helm_chart_repo
  chart      = var.helm_chart_name
  version    = var.helm_chart_version

  set {
    name  = "domain"
    value = var.domain
  }
  set {
    name  = "backend.image.repo"
    value = var.backend_image_repo
  }
  set {
    name  = "backend.image.tag"
    value = var.backend_image_tag
  }
  set {
    name  = "frontend.image.repo"
    value = var.frontend_image_repo
  }
  set {
    name  = "frontend.image.tag"
    value = var.frontend_image_tag
  }
  set {
    name  = "postgres.bundled"
    value = "false"
  }
  set {
    name  = "postgres.host"
    value = module.cloudsql.private_ip_address
  }
  set {
    name  = "postgres.port"
    value = "5432"
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
    value = module.cloudsql.additional_user_passwords[var.db_user]
  }
  set_sensitive {
    name  = "jwtSecret"
    value = random_password.jwt.result
  }

  depends_on = [
    module.gke,
    module.cloudsql,
  ]
}
