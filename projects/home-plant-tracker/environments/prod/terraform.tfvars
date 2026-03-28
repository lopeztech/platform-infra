project_id               = "home-plant-tracker-491202"
region                   = "australia-southeast1"
domain                   = "plants.lopezcloud.dev"
environment              = "prod"
github_org               = "lopeztech"
github_repo              = "platform-infra"
terraform_operator_email = "joshua.lopez.tech@gmail.com"
iap_allowed_users        = ["joshua.lopez.tech@gmail.com"]

# function_source_object is set by CI when deploying a new function version.
# For infrastructure-only changes, set this to the currently deployed object name.
# Example: function_source_object = "plants-abc123def456.zip"
