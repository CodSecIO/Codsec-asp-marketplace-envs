# ============================================================================
# TERRAFORM AND PROVIDER REQUIREMENTS
# ============================================================================

terraform {
  required_version = ">= 1.5.7"

  required_providers {
    google = {
      source = "hashicorp/google"
      # Vendored copy: exact pin relaxed so one google provider version can
      # satisfy all vendored modules; the root module constrains the version.
      version = ">= 6.41.0, < 9.0.0"
    }
  }
}
