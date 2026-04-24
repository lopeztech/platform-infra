project_id               = "home-plant-tracker-lcd"
region                   = "australia-southeast1"
domain                   = "plants.lopezcloud.dev"
environment              = "prod"
github_org               = "lopeztech"
github_repo              = "platform-infra"
terraform_operator_email = "admin@lopezcloud.dev"
iap_allowed_users        = ["admin@lopezcloud.dev"]
notification_email       = "admin@lopezcloud.dev"
monthly_budget_usd       = 20   

billing_enabled                      = true
stripe_price_home_pro_monthly        = "price_1TPcVNPhPwrCqy0VmqCNiiP2"  # from Step 2
stripe_price_home_pro_annual         = "price_1TPcVNPhPwrCqy0Vd24zM7V8"
stripe_price_landscaper_pro_monthly  = "price_1TPhACPhPwrCqy0VLzPLNVSe"
stripe_price_landscaper_pro_annual   = "price_1TPhBMPhPwrCqy0VwClrJ5s4"
# function_source_object is set by CI when deploying a new function version.
# For infrastructure-only changes, set this to the currently deployed object name.
# Example: function_source_object = "plants-abc123def456.zip"
