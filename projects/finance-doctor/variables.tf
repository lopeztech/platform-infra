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
  description = "Custom domain for the application"
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

variable "app_github_repo" {
  description = "GitHub repository name for the finance-doctor application"
  type        = string
  default     = "finance-doctor"
}

variable "terraform_operator_email" {
  description = "Email of the user or service account running terraform apply"
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
  description = "Monthly budget amount in USD"
  type        = number
  default     = 20
}
