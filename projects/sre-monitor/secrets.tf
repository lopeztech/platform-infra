# ── Secret Manager — GitHub OAuth + JWT ──────────────────────────────────────
# Secret values are set manually after terraform apply:
#
#   # GitHub OAuth App (create at https://github.com/settings/developers)
#   # Homepage URL: https://sre.lopezcloud.dev
#   # Callback URL: https://sre.lopezcloud.dev/auth/github/callback
#   echo -n "Ov23li..." | gcloud secrets versions add github-oauth-client-id --data-file=- --project=sre-monitor-lcd
#   echo -n "secret..." | gcloud secrets versions add github-oauth-client-secret --data-file=- --project=sre-monitor-lcd
#
#   # Generate a random 256-bit key for JWT signing
#   openssl rand -base64 32 | gcloud secrets versions add jwt-secret --data-file=- --project=sre-monitor-lcd

resource "google_secret_manager_secret" "github_oauth_client_id" {
  secret_id = "github-oauth-client-id"
  project   = var.project_id
  replication {
    auto {}
  }
  depends_on = [google_project_service.apis]
}

resource "google_secret_manager_secret" "github_oauth_client_secret" {
  secret_id = "github-oauth-client-secret"
  project   = var.project_id
  replication {
    auto {}
  }
  depends_on = [google_project_service.apis]
}

resource "google_secret_manager_secret" "jwt_secret" {
  secret_id = "jwt-secret"
  project   = var.project_id
  replication {
    auto {}
  }
  depends_on = [google_project_service.apis]
}

resource "google_secret_manager_secret" "github_token" {
  secret_id = "github-token"
  project   = var.project_id
  replication {
    auto {}
  }
  depends_on = [google_project_service.apis]
}

# ── Grant Cloud Functions default compute SA access to secrets ───────────────

locals {
  function_secrets = [
    google_secret_manager_secret.github_oauth_client_id.secret_id,
    google_secret_manager_secret.github_oauth_client_secret.secret_id,
    google_secret_manager_secret.jwt_secret.secret_id,
    google_secret_manager_secret.github_token.secret_id,
  ]
}

resource "google_secret_manager_secret_iam_member" "function_secret_access" {
  for_each  = toset(local.function_secrets)
  secret_id = each.value
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${data.google_compute_default_service_account.default.email}"
  project   = var.project_id
}
