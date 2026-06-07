# Vendored from CodSecIO/terraform-modules//modules/gcp/gke for the
# Marketplace package. Adjusted: exact provider pin relaxed (the root module
# constrains the version), and the in-module kubernetes/helm provider
# configurations removed - modules used with `count` cannot contain provider
# configurations, and the Marketplace root module owns cluster credentials.
terraform {
  required_version = ">= 1.5.7"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 7.12.0, < 9.0.0"
    }
  }
}
