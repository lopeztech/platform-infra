output "load_balancer_ip" {
  description = "Static IP address — create a DNS A record pointing your domain here"
  value       = google_compute_global_address.app.address
}

output "app_url" {
  description = "HTTPS URL for the application (active once DNS and cert are provisioned)"
  value       = "https://${var.domain}"
}

output "bucket_name" {
  description = "GCS bucket name for the React app"
  value       = google_storage_bucket.app.name
}

output "bucket_url" {
  description = "GCS bucket URL"
  value       = google_storage_bucket.app.url
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

output "ssl_certificate_name" {
  description = "Managed SSL certificate resource name"
  value       = google_compute_managed_ssl_certificate.app.name
}

output "artifact_registry_repo" {
  description = "Artifact Registry repo URL for Docker pushes"
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.app.repository_id}"
}

output "cloud_run_service" {
  description = "Cloud Run service name"
  value       = google_cloud_run_v2_service.app.name
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

output "github_secrets" {
  description = "Copy these values into your GitHub repository secrets for lopeztech/platform-infra"
  value = {
    HOME_PLANT_TRACKER_WIF_PROVIDER = google_iam_workload_identity_pool_provider.github.name
    HOME_PLANT_TRACKER_SA_EMAIL     = google_service_account.github_deployer.email
    GCS_BUCKET_NAME                 = google_storage_bucket.app.name
    ARTIFACT_REGISTRY_REPO          = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.app.repository_id}"
    VITE_API_BASE_URL               = "https://${google_api_gateway_gateway.app.default_hostname}"
    VITE_GOOGLE_CLIENT_ID           = "(set manually — see iap.tf for instructions)"
    VITE_API_KEY                    = "(run: terraform output -raw api_key)"
  }
}

output "app_github_secrets" {
  description = "Copy these values into GitHub Secrets for lopeztech/home-plant-tracker (function CI)"
  value = {
    HPT_FUNCTION_WIF_PROVIDER  = google_iam_workload_identity_pool_provider.github_app.name
    HPT_FUNCTION_SA_EMAIL      = google_service_account.github_deployer.email
    FUNCTION_SOURCE_BUCKET     = google_storage_bucket.function_source.name
  }
}
