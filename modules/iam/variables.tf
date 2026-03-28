variable "project_id" { type = string }
variable "env"        { type = string }

variable "github_org" {
  description = "GitHub organisation that triggers deployments"
  type        = string
  default     = "lopeztech"
}

variable "github_repo" {
  description = "GitHub repository that triggers deployments (the infrastructure repo)"
  type        = string
  default     = "platform-infra"
}
