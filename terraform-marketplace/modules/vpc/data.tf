data "google_compute_subnetwork" "subnet_status" {
  for_each = var.primary_subnets

  name    = each.key
  region  = each.value.region
  project = var.project_id

  depends_on = [module.vpc]
}
