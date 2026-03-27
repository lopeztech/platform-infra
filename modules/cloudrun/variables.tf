variable "project_id"            { type = string }
variable "region"                { type = string }
variable "env"                   { type = string }
variable "service_account_email" { type = string }
variable "secret_ids"            { type = map(string) }
variable "gcs_bucket_names"      { type = map(string) }
variable "pubsub_topic_ids"      { type = map(string) }
variable "firestore_database"    { type = string }
