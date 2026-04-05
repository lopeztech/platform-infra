output "project_id" {
  value = var.project_id
}

output "deployer_sa_email" {
  description = "GitHub Actions deployer service account email"
  value       = google_service_account.github_deployer.email
}

output "wif_provider_name" {
  description = "Full resource name of the WIF provider (for FINANCE_DOCTOR_WIF_PROVIDER secret)"
  value       = google_iam_workload_identity_pool_provider.github.name
}

output "app_wif_provider_name" {
  description = "Full resource name of the app repo WIF provider"
  value       = google_iam_workload_identity_pool_provider.github_app.name
}

output "google_client_id_secret_id" {
  description = "Secret Manager resource ID for Google OAuth Client ID"
  value       = google_secret_manager_secret.google_client_id.secret_id
}

output "google_client_secret_secret_id" {
  description = "Secret Manager resource ID for Google OAuth Client Secret"
  value       = google_secret_manager_secret.google_client_secret.secret_id
}

output "auth_secret_secret_id" {
  description = "Secret Manager resource ID for NextAuth secret"
  value       = google_secret_manager_secret.auth_secret.secret_id
}

output "cloud_run_url" {
  description = "Cloud Run service URL"
  value       = google_cloud_run_v2_service.app.uri
}

output "artifact_registry_repo" {
  description = "Artifact Registry repository path for docker push"
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.app.repository_id}"
}

output "app_runtime_sa_email" {
  description = "Cloud Run runtime service account email"
  value       = google_service_account.app_runtime.email
}
