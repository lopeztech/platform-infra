variable "project_id" { type = string }
variable "region"     { type = string }
variable "env" {
  type    = string
  default = ""
}

variable "kms_key_ids" {
  description = "Map of layer name → KMS crypto key ID"
  type        = map(string)
}

variable "pubsub_topic_id" {
  description = "Pub/Sub topic ID for GCS Bronze bucket finalize notifications"
  type        = string
}

variable "cors_origins" {
  description = "Allowed CORS origins for the raw (Bronze) bucket (browser uploads via signed URLs)"
  type        = list(string)
  default     = []
}

variable "upload_sa_email" {
  description = "Service account email that uploads to the raw bucket (granted objectAdmin)"
  type        = string
  default     = ""
}

variable "validator_sa_email" {
  description = "Service account email for the validator function (reads raw, writes staging + rejected)"
  type        = string
  default     = ""
}
