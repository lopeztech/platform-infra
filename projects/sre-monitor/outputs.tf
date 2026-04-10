output "app_url" {
  description = "HTTPS URL for the application"
  value       = "https://${var.domain}"
}

output "firebase_hosting_site_id" {
  description = "Firebase Hosting site ID — use as the deploy target"
  value       = google_firebase_hosting_site.app.site_id
}

output "firebase_hosting_default_url" {
  description = "Firebase Hosting default URL"
  value       = "https://${google_firebase_hosting_site.app.site_id}.web.app"
}

output "artifact_registry_repo" {
  description = "Artifact Registry repo URL for Docker pushes"
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.app.repository_id}"
}

output "cloud_run_service" {
  description = "Cloud Run service name"
  value       = google_cloud_run_v2_service.app.name
}

output "workload_identity_provider" {
  description = "WIF provider resource name — set as SRE_MONITOR_WIF_PROVIDER in GitHub Secrets"
  value       = google_iam_workload_identity_pool_provider.github.name
}

output "service_account_email" {
  description = "Deployer SA email — set as SRE_MONITOR_SA_EMAIL in GitHub Secrets"
  value       = google_service_account.github_deployer.email
}

output "app_workload_identity_provider" {
  description = "WIF provider for the app repo — set as GCP_WORKLOAD_IDENTITY_PROVIDER in sre-monitor GitHub vars"
  value       = google_iam_workload_identity_pool_provider.github_app.name
}

output "github_secrets_platform_infra" {
  description = "Copy these values into lopeztech/platform-infra GitHub Secrets"
  value = {
    SRE_MONITOR_WIF_PROVIDER = google_iam_workload_identity_pool_provider.github.name
    SRE_MONITOR_SA_EMAIL     = google_service_account.github_deployer.email
    ARTIFACT_REGISTRY_REPO   = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.app.repository_id}"
  }
}

output "github_vars_sre_monitor" {
  description = "Copy these values into lopeztech/sre-monitor GitHub repository variables"
  value = {
    GCP_WORKLOAD_IDENTITY_PROVIDER = google_iam_workload_identity_pool_provider.github_app.name
    GCP_SERVICE_ACCOUNT            = google_service_account.github_deployer.email
    FIREBASE_HOSTING_SITE_ID       = google_firebase_hosting_site.app.site_id
  }
}
