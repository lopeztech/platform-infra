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
  description = "Public custom domain for the SPA — served by Firebase Hosting."
  type        = string
}

variable "environment" {
  description = "Deployment environment label (prod, staging, etc.)"
  type        = string
  default     = "prod"
}

variable "github_org" {
  description = "GitHub organisation or username that owns the repositories"
  type        = string
  default     = "lopeztech"
}

variable "github_repo" {
  description = "GitHub repository name that triggers terraform (the infra repo)"
  type        = string
  default     = "platform-infra"
}

variable "app_github_repo" {
  description = "GitHub repository name for the fantasy-coach application code"
  type        = string
  default     = "fantasy-coach"
}

variable "terraform_operator_email" {
  description = "Email (user:) or SA (serviceAccount:) that runs terraform apply"
  type        = string
}

variable "notification_email" {
  description = "Email address for monitoring alert notifications"
  type        = string
  default     = "admin@lopezcloud.dev"
}

variable "billing_account" {
  description = "GCP billing account ID (format: XXXXXX-XXXXXX-XXXXXX)"
  type        = string
}

variable "monthly_budget_usd" {
  description = "Monthly budget in USD"
  type        = number
  default     = 20
}
