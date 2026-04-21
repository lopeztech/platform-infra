variable "project_id" {
  description = "Google Cloud project ID"
  type        = string
}

variable "region" {
  description = "Google Cloud region for regional resources"
  type        = string
  default     = "australia-southeast1"
}

variable "domain" {
  description = "Custom domain for the application (e.g. plants.example.com). Must have a DNS A record pointing to the load balancer IP after apply."
  type        = string
}

variable "environment" {
  description = "Deployment environment label (prod, staging, etc.)"
  type        = string
  default     = "prod"
}

variable "github_org" {
  description = "GitHub organisation or username that owns the infrastructure repository"
  type        = string
  default     = "lopeztech"
}

variable "github_repo" {
  description = "GitHub repository name that triggers deployments (the infrastructure repo)"
  type        = string
  default     = "platform-infra"
}

variable "terraform_operator_email" {
  description = "Email of the user or service account running terraform apply (e.g. you@example.com). Will be granted the IAM roles required to provision all resources."
  type        = string
}

variable "iap_allowed_users" {
  description = "List of Google account emails permitted to access the app via IAP"
  type        = list(string)
  default     = []
}

variable "notification_email" {
  description = "Email address for monitoring alert notifications"
  type        = string
  default     = "admin@lopezcloud.dev"
}

variable "function_source_object" {
  description = "GCS object name of the pre-built Cloud Function ZIP (e.g. plants-abc123def.zip). Built and uploaded by the home-plant-tracker CI pipeline before triggering Terraform."
  type        = string
}

variable "ml_admin_token" {
  description = "Admin token for ML export and anomaly scan endpoints (x-admin-token header)"
  type        = string
  sensitive   = true
}

variable "billing_account" {
  description = "GCP billing account ID (format: XXXXXX-XXXXXX-XXXXXX)"
  type        = string
}

variable "monthly_budget_usd" {
  description = "Monthly budget amount in USD"
  type        = number
  default     = 20
}

# ── Stripe billing ──────────────────────────────────────────────────────────
# Flip to true after STRIPE_SECRET_KEY + STRIPE_WEBHOOK_SECRET are populated
# in Secret Manager and Price IDs below are set. Until then, the backend
# reports tier=free for everyone and all tier gates / quotas are no-ops.

variable "billing_enabled" {
  description = "Whether to enable Stripe subscription billing (requires populated secrets + price IDs)."
  type        = bool
  default     = false
}

variable "stripe_price_home_pro_monthly" {
  description = "Stripe Price ID (price_...) for Home Pro monthly subscription."
  type        = string
  default     = ""
}

variable "stripe_price_home_pro_annual" {
  description = "Stripe Price ID (price_...) for Home Pro annual subscription."
  type        = string
  default     = ""
}

variable "stripe_price_landscaper_pro_monthly" {
  description = "Stripe Price ID (price_...) for Landscaper Pro monthly subscription."
  type        = string
  default     = ""
}

variable "stripe_price_landscaper_pro_annual" {
  description = "Stripe Price ID (price_...) for Landscaper Pro annual subscription."
  type        = string
  default     = ""
}
