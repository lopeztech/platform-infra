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
