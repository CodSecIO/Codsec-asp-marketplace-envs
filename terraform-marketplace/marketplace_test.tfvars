# Used by Marketplace to validate the module (terraform plan --var-file).
#
# Do not include variables Marketplace provides:
# - project_id
# - helm_chart_repo / helm_chart_name / helm_chart_version
# - any variables declared in schema.yaml (image repos/tags)

create_cluster = true
create_network = true

domain = "asp.example.com"
zone   = "us-central1-a"

# The validation project is throwaway - do not block its teardown.
db_deletion_protection = false
