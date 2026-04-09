output "app_url" {
  description = "HTTPS URL for the application"
  value       = "https://${var.domain}"
}

output "firebase_hosting_site_id" {
  description = "Firebase Hosting site ID — use as the deploy target in firebase.json"
  value       = google_firebase_hosting_site.plant_tracker.site_id
}

output "firebase_hosting_default_url" {
  description = "Firebase Hosting default URL (before custom domain verification)"
  value       = "https://${google_firebase_hosting_site.plant_tracker.site_id}.web.app"
}

output "firebase_hosting_custom_domain_dns" {
  description = "DNS records required for Firebase Hosting custom domain — set these in Cloudflare (DNS-only, grey cloud)"
  value       = google_firebase_hosting_custom_domain.plant_tracker.required_dns_updates
}

output "images_bucket_name" {
  description = "GCS bucket for user-uploaded images (floorplans + plant photos)"
  value       = google_storage_bucket.images.name
}

output "function_source_bucket" {
  description = "GCS bucket where the home-plant-tracker CI uploads function ZIPs"
  value       = google_storage_bucket.function_source.name
}

output "workload_identity_provider" {
  description = "WIF provider resource name — set as HOME_PLANT_TRACKER_WIF_PROVIDER in GitHub Secrets for lopeztech/platform-infra"
  value       = google_iam_workload_identity_pool_provider.github.name
}

output "app_workload_identity_provider" {
  description = "WIF provider resource name for home-plant-tracker app CI — set as HPT_FUNCTION_WIF_PROVIDER in GitHub Secrets for lopeztech/home-plant-tracker"
  value       = google_iam_workload_identity_pool_provider.github_app.name
}

output "service_account_email" {
  description = "Deployer service account email — set as HOME_PLANT_TRACKER_SA_EMAIL in GitHub Secrets for lopeztech/platform-infra"
  value       = google_service_account.github_deployer.email
}

output "artifact_registry_repo" {
  description = "Artifact Registry repo URL for Docker pushes"
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.app.repository_id}"
}

output "api_gateway_url" {
  description = "API Gateway base URL — use as VITE_API_BASE_URL"
  value       = "https://${google_api_gateway_gateway.app.default_hostname}"
}

output "api_key" {
  description = "API key for the Plant Tracker API — set as VITE_API_KEY in GitHub Secrets and .env.local"
  value       = google_apikeys_key.app.key_string
  sensitive   = true
}

output "function_url" {
  description = "Cloud Function URL (direct, behind API Gateway)"
  value       = google_cloudfunctions2_function.plants.service_config[0].uri
}

output "ml_data_bucket" {
  description = "GCS bucket for ML training data exports"
  value       = google_storage_bucket.ml_data.name
}

output "github_secrets" {
  description = "Copy these values into your GitHub repository secrets for lopeztech/platform-infra"
  value = {
    HOME_PLANT_TRACKER_WIF_PROVIDER = google_iam_workload_identity_pool_provider.github.name
    HOME_PLANT_TRACKER_SA_EMAIL     = google_service_account.github_deployer.email
    ARTIFACT_REGISTRY_REPO          = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.app.repository_id}"
    VITE_API_BASE_URL               = "https://${google_api_gateway_gateway.app.default_hostname}"
    VITE_GOOGLE_CLIENT_ID           = "(set manually — see iap.tf for instructions)"
    VITE_API_KEY                    = "(run: terraform output -raw api_key)"
  }
}

output "app_github_secrets" {
  description = "Copy these values into GitHub Secrets for lopeztech/home-plant-tracker (function + Firebase deploy CI)"
  value = {
    HPT_FUNCTION_WIF_PROVIDER  = google_iam_workload_identity_pool_provider.github_app.name
    HPT_FUNCTION_SA_EMAIL      = google_service_account.github_deployer.email
    FUNCTION_SOURCE_BUCKET     = google_storage_bucket.function_source.name
    FIREBASE_PROJECT_ID        = var.project_id
    FIREBASE_HOSTING_SITE_ID   = google_firebase_hosting_site.plant_tracker.site_id
  }
}
