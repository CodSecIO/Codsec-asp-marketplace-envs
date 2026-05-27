variable "project_id" {
  description = "GCP project ID to deploy ASP into."
  type        = string
}

variable "region" {
  description = "GCP region for all resources."
  type        = string
  default     = "us-central1"
}

variable "name_prefix" {
  description = "Prefix applied to all resource names."
  type        = string
  default     = "asp"
}

variable "db_tier" {
  description = "CloudSQL machine tier."
  type        = string
  default     = "db-custom-2-7680"
}

variable "redis_memory_gb" {
  description = "Memorystore Redis capacity in GiB."
  type        = number
  default     = 1
}
