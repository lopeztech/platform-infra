project_id               = "home-plant-tracker-lcd"
region                   = "australia-southeast1"
domain                   = "plants.lopezcloud.dev"
environment              = "prod"
github_org               = "lopeztech"
github_repo              = "platform-infra"
terraform_operator_email = "admin@lopezcloud.dev"
iap_allowed_users        = ["admin@lopezcloud.dev"]

# function_source_object is set by CI when deploying a new function version.
# For infrastructure-only changes, set this to the currently deployed object name.
# Example: function_source_object = "plants-abc123def456.zip"
