# ── OAuth Consent Screen + Client ID ─────────────────────────────────────────
# Google OAuth brands cannot be created via API for personal (non-Organisation)
# GCP projects. Create the OAuth client manually then set the credentials in
# the finance-doctor app's .env.local file.
#
# One-time manual setup:
#   1. Cloud Console → APIs & Services → OAuth consent screen
#      - User type: External → Create
#      - App name: Finance Doctor
#      - Support email: admin@lopezcloud.dev
#      - Scopes: email, profile, openid
#      - Save and continue through all steps
#   2. Cloud Console → APIs & Services → Credentials → Create Credentials
#      → OAuth 2.0 Client ID
#      - Application type: Web application
#      - Name: finance-doctor-web
#      - Authorised JavaScript origins:
#          http://localhost:3000
#          https://<domain>
#      - Authorised redirect URIs:
#          http://localhost:3000/api/auth/callback/google
#          https://<domain>/api/auth/callback/google
#      - Copy the Client ID and Client Secret
#   3. Store secrets:
#      - Local dev:  set GOOGLE_CLIENT_ID and GOOGLE_CLIENT_SECRET in .env.local
#      - Production: store in Secret Manager (see secrets.tf)

# Secret Manager entries for OAuth credentials (values set manually via console)

resource "google_secret_manager_secret" "google_client_id" {
  secret_id = "google-oauth-client-id"
  project   = var.project_id
  labels    = local.labels

  replication {
    auto {}
  }

  depends_on = [google_project_service.apis]
}

resource "google_secret_manager_secret" "google_client_secret" {
  secret_id = "google-oauth-client-secret"
  project   = var.project_id
  labels    = local.labels

  replication {
    auto {}
  }

  depends_on = [google_project_service.apis]
}

resource "google_secret_manager_secret" "auth_secret" {
  secret_id = "nextauth-secret"
  project   = var.project_id
  labels    = local.labels

  replication {
    auto {}
  }

  depends_on = [google_project_service.apis]
}
