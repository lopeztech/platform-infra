variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "env" {
  description = "Environment suffix for resource naming (e.g. 'prod')"
  type        = string
  default     = ""
}

variable "billing_account" {
  description = "GCP billing account ID (format: XXXXXX-XXXXXX-XXXXXX)"
  type        = string
}

variable "monthly_budget_usd" {
  description = "Monthly budget amount in USD"
  type        = number
}

variable "notification_email" {
  description = "Email address for budget alert notifications"
  type        = string
}

variable "threshold_percentages" {
  description = "List of threshold percentages (0.0-1.0) that trigger alerts"
  type        = list(number)
  default     = [0.5, 0.8, 1.0]
}

variable "currency_code" {
  description = "Currency code matching the billing account (e.g. AUD, USD)"
  type        = string
  default     = "AUD"
}
