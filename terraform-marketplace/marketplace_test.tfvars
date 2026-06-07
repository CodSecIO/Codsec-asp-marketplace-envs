# Used by Marketplace to validate the module (terraform plan --var-file).
#
# Do not include variables Marketplace provides:
# - project_id
# - helm_chart_repo / helm_chart_name / helm_chart_version
# - any variables declared in schema.yaml (image repos/tags)
#
# Defaults already provision the full greenfield stack (VPC + GKE + Cloud SQL
# + app), so only test-specific overrides live here.

# The validation project is throwaway - do not block its teardown.
db_deletion_protection = false
