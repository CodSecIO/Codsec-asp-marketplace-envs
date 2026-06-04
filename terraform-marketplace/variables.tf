variable "project_id" {
  description = "Customer GCP project to deploy ASP into."
  type        = string
}

variable "region" {
  description = "GCP region for all resources."
  type        = string
  default     = "us-central1"
}

variable "name_prefix" {
  description = "Prefix applied to all created resource names."
  type        = string
  default     = "asp"
}

variable "domain" {
  description = "Public domain for the chat UI (e.g. asp.example.com). Point its DNS at the ingress_ip output after apply."
  type        = string
}

variable "db_tier" {
  description = "Cloud SQL machine tier for the managed PostgreSQL instance."
  type        = string
  default     = "db-custom-2-7680"
}

variable "db_deletion_protection" {
  description = "Protect the Cloud SQL instance from deletion. Keep true for production; set false for throwaway verify/test."
  type        = bool
  default     = true
}

variable "gke_deletion_protection" {
  description = "Protect the GKE cluster from deletion."
  type        = bool
  default     = false
}

# --- App images. Marketplace binds the billing entitlement to these via the
# --- image declarations in schema.yaml; the values below are the published
# --- Artifact Registry paths.
variable "backend_image" {
  description = "Backend (primary) image repository, without tag."
  type        = string
  default     = "us-docker.pkg.dev/codsec-public/asp-deployer/asp"
}

variable "frontend_image" {
  description = "Frontend image repository, without tag."
  type        = string
  default     = "us-docker.pkg.dev/codsec-public/asp-deployer/asp/frontend"
}

variable "image_tag" {
  description = "Release track tag shared by all images (e.g. 1.0)."
  type        = string
  default     = "1.0"
}

# --- Helm chart (OCI artifact in Artifact Registry). Final path is confirmed
# --- when the chart is pushed (see Publish task); parameterized so the module
# --- does not hard-code an unverified ref.
variable "chart_oci_ref" {
  description = "OCI reference to the app Helm chart (oci://HOST/PROJECT/REPO/CHART)."
  type        = string
  default     = "oci://us-docker.pkg.dev/codsec-public/asp-deployer/chart"
}

variable "chart_version" {
  description = "Version of the Helm chart to deploy."
  type        = string
  default     = "1.0.0"
}

variable "db_name" {
  description = "Application database name."
  type        = string
  default     = "asp"
}

variable "db_user" {
  description = "Application database user."
  type        = string
  default     = "asp"
}
