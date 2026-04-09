output "gcs_bucket_names"       { value = module.gcs.bucket_names }
output "pubsub_topic_ids"       { value = module.pubsub.topic_ids }
output "bigquery_dataset_ids"   { value = module.bigquery.dataset_ids }
output "service_account_emails" { value = module.iam.sa_emails }
output "firestore_database"     { value = module.firestore.database_name }
output "wif_provider_name"      { value = module.iam.wif_provider_name }
output "app_url"                { value = "https://${var.domain}" }

output "firebase_hosting_site_id" {
  value       = google_firebase_hosting_site.data_feeder.site_id
  description = "Firebase Hosting site ID (deployment target)"
}

output "firebase_hosting_default_url" {
  value       = "https://${google_firebase_hosting_site.data_feeder.site_id}.web.app"
  description = "Firebase Hosting default URL"
}
