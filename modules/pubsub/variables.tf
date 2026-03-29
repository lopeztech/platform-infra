variable "project_id" { type = string }
variable "env" {
  type    = string
  default = ""
}

variable "upload_sa_email" {
  description = "Service account email for the upload API (granted pubsub.publisher on file-uploaded topic for retrigger)"
  type        = string
  default     = ""
}
