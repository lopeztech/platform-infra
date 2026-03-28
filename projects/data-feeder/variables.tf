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
