variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region for all resources"
  type        = string
  default     = "australia-southeast1"
}

variable "domain" {
  description = "Custom domain for the application"
  type        = string
  default     = "datafeeder.lopezcloud.dev"
}

variable "notification_email" {
  description = "Email address for monitoring alert notifications"
  type        = string
  default     = "admin@lopezcloud.dev"
}
