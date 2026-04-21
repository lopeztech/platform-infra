# Publishes the Firebase Web App config to Secret Manager so the app-repo
# SPA deploy workflow can fetch VITE_FIREBASE_* values at build time without
# hard-coding them in workflow YAML. api_key and auth_domain are semi-
# sensitive; project_id and app_id are public, but keeping all four in Secret
# Manager gives the deploy workflow one consistent fetch path.

locals {
  firebase_web_secrets = {
    "firebase-web-api-key"     = data.google_firebase_web_app_config.app.api_key
    "firebase-web-auth-domain" = data.google_firebase_web_app_config.app.auth_domain
    "firebase-web-project-id"  = var.project_id
    "firebase-web-app-id"      = google_firebase_web_app.app.app_id
  }
}

resource "google_secret_manager_secret" "firebase_web" {
  for_each = local.firebase_web_secrets

  project   = var.project_id
  secret_id = each.key
  labels    = local.labels

  replication {
    auto {}
  }

  depends_on = [google_project_service.apis]
}

resource "google_secret_manager_secret_version" "firebase_web" {
  for_each = local.firebase_web_secrets

  secret      = google_secret_manager_secret.firebase_web[each.key].id
  secret_data = each.value
}

# Deployer SA needs to read these secrets at SPA build time (see the
# forthcoming web-deploy.yml workflow in lopeztech/fantasy-coach#72).
resource "google_secret_manager_secret_iam_member" "firebase_web_deployer" {
  for_each = local.firebase_web_secrets

  project   = var.project_id
  secret_id = google_secret_manager_secret.firebase_web[each.key].secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.github_deployer.email}"
}
