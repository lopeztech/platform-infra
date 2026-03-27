variable "project_id"         { type = string }
variable "region"             { type = string; default = "us-central1" }
variable "env"                {
  type = string
  validation {
    condition     = contains(["dev", "staging", "prod"], var.env)
    error_message = "env must be one of: dev, staging, prod."
  }
}
variable "platform_infra_ref" { type = string; default = "main" }
