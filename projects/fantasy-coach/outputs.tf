output "project_id" {
  value       = var.project_id
  description = "GCP project hosting fantasy-coach"
}

output "region" {
  value = var.region
}

output "runtime_sa_email" {
  value       = google_service_account.runtime.email
  description = "Cloud Run runtime service account email"
}

output "deployer_sa_email" {
  value       = google_service_account.github_deployer.email
  description = "GitHub Actions deployer service account email (→ FANTASY_COACH_DEPLOYER_SA secret in both repos)"
}

output "wif_provider_name" {
  value       = google_iam_workload_identity_pool_provider.github.name
  description = "Platform-infra WIF provider full resource name (→ FANTASY_COACH_WIF_PROVIDER secret in platform-infra)"
}

output "app_wif_provider_name" {
  value       = google_iam_workload_identity_pool_provider.github_app.name
  description = "App-repo WIF provider full resource name (→ FANTASY_COACH_WIF_PROVIDER secret in lopeztech/fantasy-coach)"
}

output "cloud_run_service_name" {
  value = google_cloud_run_v2_service.api.name
}

output "artifact_registry_repo" {
  value       = google_artifact_registry_repository.app.repository_id
  description = "Repository ID for pushing images (full path: {region}-docker.pkg.dev/{project}/{repo})"
}
