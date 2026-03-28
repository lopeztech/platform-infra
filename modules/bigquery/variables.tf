variable "project_id" { type = string }
variable "region"     { type = string }
variable "env" {
  type    = string
  default = ""
}

variable "kms_key_id" {
  description = "KMS crypto key ID for BigQuery default encryption"
  type        = string
}
