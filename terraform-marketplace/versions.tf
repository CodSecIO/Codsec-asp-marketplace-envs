terraform {
  required_version = ">= 1.5.7"

  required_providers {
    google = {
      source = "hashicorp/google"
      # Lowest version satisfying every vendored module (gke requires >= 7.12).
      version = "~> 7.12"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 7.12"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.17"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.38"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.5"
    }
  }
}
