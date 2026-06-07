# --------------------------------------------------------------------------
# Provided by Marketplace at deploy time - do not set in marketplace_test.tfvars
# --------------------------------------------------------------------------

variable "project_id" {
  type        = string
  description = "GCP project id"
}

variable "helm_chart_repo" {
  type        = string
  description = "Helm chart repository (injected by Marketplace)"
  # Default = the published artifact; Marketplace injection overrides it.
  default = "oci://us-docker.pkg.dev/codsec-public/asp-charts"
}

variable "helm_chart_name" {
  type        = string
  description = "Helm chart name (injected by Marketplace)"
  # Default = the published artifact; Marketplace injection overrides it.
  default = "asp"
}

variable "helm_chart_version" {
  type        = string
  description = "Helm chart version (injected by Marketplace)"
  # Default = the published artifact; Marketplace injection overrides it.
  default = "1.0.0"
}

# Declared in schema.yaml - Marketplace substitutes the published image paths.

variable "backend_image_repo" {
  type        = string
  description = "Backend (primary) image repository, without tag"
  # Default = the published artifact; Marketplace injection overrides it.
  default = "us-docker.pkg.dev/codsec-public/asp-charts/backend"
}

variable "backend_image_tag" {
  type        = string
  description = "Backend image tag"
  # Default = the published artifact; Marketplace injection overrides it.
  default = "1.0"
}

variable "frontend_image_repo" {
  type        = string
  description = "Frontend image repository, without tag"
  # Default = the published artifact; Marketplace injection overrides it.
  default = "us-docker.pkg.dev/codsec-public/asp-charts/frontend"
}

variable "frontend_image_tag" {
  type        = string
  description = "Frontend image tag"
  # Default = the published artifact; Marketplace injection overrides it.
  default = "1.0"
}

# --------------------------------------------------------------------------
# App
# --------------------------------------------------------------------------

variable "domain" {
  type        = string
  description = "Public domain for the chat UI (e.g. asp.example.com). Point its DNS at the ingress IP after deploy."
  # Placeholder default so validation plans cleanly even if the harness
  # supplies no tfvars; customers set their real domain in the deploy form.
  default = "asp.example.com"
}

# Required by Marketplace UI deployments: injected with the deployment name
# the customer chooses, and used as the prefix for every created resource so
# multiple deployments in one project cannot collide.
variable "goog_cm_deployment_name" {
  type        = string
  description = "Deployment name; prefix applied to created resource names"
  default     = "asp"
}

variable "environment" {
  type        = string
  description = "Environment label used in created resource names"
  default     = "prod"
}

variable "namespace" {
  type        = string
  description = "Kubernetes namespace for the app (defaults to the deployment name)"
  default     = ""
}

variable "helm_release_name" {
  type        = string
  description = "Helm release name (defaults to asp)"
  default     = ""
}

variable "region" {
  type        = string
  description = "GCP region for all created resources"
  default     = "us-central1"
}

# --------------------------------------------------------------------------
# Cluster: existing by default, opt-in creation
# --------------------------------------------------------------------------

variable "create_cluster" {
  type        = bool
  description = "Create a dedicated GKE cluster. When false (default), ASP deploys onto the existing cluster named in cluster_name."
  default     = false
}

variable "cluster_name" {
  type        = string
  description = "Existing cluster name (required when create_cluster = false). When create_cluster = true and this is empty, the name is derived as <deployment-name>-<environment>-gke."
  default     = ""
}

variable "cluster_location" {
  type        = string
  description = "Location (region or zone) of the existing cluster. Defaults to region."
  default     = ""
}

variable "kubernetes_version" {
  type        = string
  description = "Kubernetes version for a created cluster"
  default     = "1.33"
}

variable "regional" {
  type        = bool
  description = "Create a regional (true) or zonal (false) cluster"
  default     = false
}

variable "zone" {
  type        = string
  description = "Zone for a zonal created cluster (e.g. us-central1-a). Empty picks the first available zone in the region."
  default     = ""
}

# Simple primitives instead of a node-pool map: the Marketplace Deploy Config
# UI does not support complex variable types (rejects map(any)). The pool map
# the vendored gke module expects is built in gke.tf from these.

variable "node_machine_type" {
  type        = string
  description = "Machine type for the created cluster's node pool"
  default     = "e2-standard-4"
}

variable "node_min_count" {
  type        = number
  description = "Node pool autoscaling minimum"
  default     = 1
}

variable "node_max_count" {
  type        = number
  description = "Node pool autoscaling maximum"
  default     = 5
}

# --------------------------------------------------------------------------
# Network: existing by default, opt-in creation
# --------------------------------------------------------------------------

variable "create_network" {
  type        = bool
  description = "Create a dedicated VPC (with subnet, GKE secondary ranges, and Private Services Access). When false (default), the existing network below is used and it MUST already have a Private Services Access connection for Cloud SQL private IP."
  default     = false
}

variable "network_name" {
  type        = string
  description = "Existing VPC name (used when create_network = false)"
  default     = "default"
}

variable "subnetwork_name" {
  type        = string
  description = "Existing subnetwork name (used when create_network = false)"
  default     = "default"
}

variable "network_cidr" {
  type        = string
  description = "Base CIDR for a created VPC"
  default     = "10.2.0.0/16"
}

variable "ip_range_pods" {
  type        = string
  description = "Name of the pods secondary range when creating a cluster in an existing network"
  default     = ""
}

variable "ip_range_services" {
  type        = string
  description = "Name of the services secondary range when creating a cluster in an existing network"
  default     = ""
}

# --------------------------------------------------------------------------
# Database (managed Cloud SQL PostgreSQL)
# --------------------------------------------------------------------------

variable "db_tier" {
  type        = string
  description = "Cloud SQL machine tier"
  default     = "db-custom-1-3840"
}

variable "db_availability_type" {
  type        = string
  description = "Cloud SQL availability type (ZONAL or REGIONAL)"
  default     = "ZONAL"
}

variable "db_disk_size" {
  type        = number
  description = "Cloud SQL disk size in GB (autoresizes up to 5x)"
  default     = 20
}

variable "db_name" {
  type        = string
  description = "Application database name"
  default     = "asp"
}

variable "db_user" {
  type        = string
  description = "Application database user"
  default     = "asp"
}

variable "db_deletion_protection" {
  type        = bool
  description = "Protect the Cloud SQL instance from deletion. Keep true in production; deleting the deployment with this enabled requires disabling it first."
  default     = true
}
