# Google Cloud Marketplace "Terraform Kubernetes app" root module for ASP.
#
# Shape follows Google's starter module
# (marketplace-tools/docs/terraform-k8s-app/starter-terraform-module):
# providers live in this root module, the cluster and network are EXISTING
# resources by default (create_cluster / create_network opt-in flags), and
# Marketplace injects project_id, helm_chart_repo/name/version, and the image
# variables declared in schema.yaml at deploy time.
#
# The vendored modules under modules/ are copies of our production modules
# from CodSecIO/terraform-modules (that repo is private; Infrastructure
# Manager cannot fetch it, so the code ships inside this package).

provider "google" {
  project = var.project_id
}

provider "google-beta" {
  project = var.project_id
}

data "google_client_config" "default" {}

# Enable required APIs once, at the root. The vendored modules' own API
# resources are disabled (enable_apis = false) so two resources never manage
# the same service.
module "project_services" {
  source  = "terraform-google-modules/project-factory/google//modules/project_services"
  version = "~> 18.0"

  project_id                  = var.project_id
  disable_services_on_destroy = false
  disable_dependent_services  = false
  activate_apis = [
    "cloudresourcemanager.googleapis.com",
    "compute.googleapis.com",
    "config.googleapis.com",
    "container.googleapis.com",
    "servicenetworking.googleapis.com",
    "sqladmin.googleapis.com",
    "secretmanager.googleapis.com",
  ]
}

# JWT signing secret for the backend, generated at deploy time. Lives only in
# Terraform state and the in-cluster Secret; never exposed as an output.
resource "random_password" "jwt" {
  length  = 48
  special = false
}
