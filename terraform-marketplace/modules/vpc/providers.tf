terraform {
  required_version = ">= 1.9.5"

  required_providers {
    google = {
      source = "hashicorp/google"
      # Vendored copy: exact pin relaxed so one google provider version can
      # satisfy all vendored modules; the root module constrains the version.
      version = ">= 6.37.0, < 9.0.0"
    }
  }
}
