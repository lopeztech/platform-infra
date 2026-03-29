variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "env" {
  description = "Environment suffix for resource naming (e.g. 'prod')"
  type        = string
  default     = ""
}

variable "notification_email" {
  description = "Email address for alert notifications"
  type        = string
}

variable "services" {
  description = "Map of service name to monitoring config"
  type = map(object({
    domain       = string
    path         = optional(string, "/health")
    display_name = optional(string)
  }))
}
