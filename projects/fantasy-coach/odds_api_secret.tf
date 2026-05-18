# ── odds-api-key Secret Manager access (fantasy-coach#280) ───────────────────
# Grants the runtime SA read access to the the-odds-api.com key used by the
# precompute Cloud Run Job to fetch NRL totals (over/under) lines for the
# Betting Tips card.
#
# The secret itself is created out-of-band via ``gcloud secrets create
# odds-api-key`` because its value is a third-party API key that should never
# enter Terraform state. Rotation: ``gcloud secrets versions add`` ; Cloud Run
# picks up the new ``:latest`` version on the next revision roll (see
# docs/secrets.md in the app repo).
#
# Only the precompute Job uses the key. The API service never reads it, so no
# grant is needed there.

resource "google_secret_manager_secret_iam_member" "odds_api_key_runtime" {
  project   = var.project_id
  secret_id = "odds-api-key"
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.runtime.email}"
}
