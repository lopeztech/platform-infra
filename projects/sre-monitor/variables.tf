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
  description = "Custom domain for the application (e.g. sre.lopezcloud.dev). Must have a DNS A record pointing to the load balancer IP after apply."
  type        = string
}

variable "environment" {
  description = "Deployment environment label"
  type        = string
  default     = "prod"
}

variable "github_org" {
  description = "GitHub organisation that owns the infrastructure repository"
  type        = string
  default     = "lopeztech"
}

variable "github_repo" {
  description = "GitHub repository that triggers deployments (the infrastructure repo)"
  type        = string
  default     = "platform-infra"
}

variable "app_github_repo" {
  description = "GitHub repository for the application code (deploys app artifacts to GCS)"
  type        = string
  default     = "sre-monitor"
}

variable "terraform_operator_email" {
  description = "Email of the user or service account running terraform apply. Will be granted the minimum IAM roles needed to provision resources."
  type        = string
}

variable "notification_email" {
  description = "Email address for monitoring alert notifications"
  type        = string
  default     = "admin@lopezcloud.dev"
}

variable "gcp_billing_table" {
  description = "BigQuery table name for billing export (format: gcp_billing_export_v1_XXXXXX)"
  type        = string
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
