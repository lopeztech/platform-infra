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

# ── Firebase Hosting / Web App outputs ──────────────────────────────────────

output "firebase_hosting_site_id" {
  description = "Firebase Hosting site id — target for `firebase deploy --only hosting`"
  value       = google_firebase_hosting_site.app.site_id
}

output "firebase_hosting_default_url" {
  description = "Default *.web.app URL for the Hosting site (rollback target)"
  value       = "https://${google_firebase_hosting_site.app.site_id}.web.app"
}

output "firebase_hosting_custom_domain" {
  description = "Public custom domain the SPA is served from"
  value       = google_firebase_hosting_custom_domain.app.custom_domain
}

output "firebase_web_app_id" {
  description = "Firebase Web App ID — used by the SPA build"
  value       = google_firebase_web_app.app.app_id
}

output "firebase_web_secret_ids" {
  description = "Secret Manager IDs holding the Firebase Web App config (→ VITE_FIREBASE_* env vars at build time)"
  value       = { for k, s in google_secret_manager_secret.firebase_web : k => s.secret_id }
}

# ── Model artefact bucket (fantasy-coach#93) ────────────────────────────────

output "models_bucket_name" {
  description = "GCS bucket holding trained model artefacts (precompute Job downloads from here)"
  value       = google_storage_bucket.models.name
}

output "models_bucket_latest_logistic_uri" {
  description = "Canonical gs:// URI of the logistic artefact the Job downloads at startup (→ FANTASY_COACH_MODEL_GCS_URI)"
  value       = "gs://${google_storage_bucket.models.name}/logistic/latest.joblib"
}
