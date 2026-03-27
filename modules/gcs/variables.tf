variable "project_id" { type = string }
variable "region"     { type = string }
variable "env"        { type = string }

variable "kms_key_ids" {
  description = "Map of layer name → KMS crypto key ID"
  type        = map(string)
}

variable "pubsub_topic_id" {
  description = "Pub/Sub topic ID for GCS Bronze bucket finalize notifications"
  type        = string
}
