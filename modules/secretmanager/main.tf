locals {
  sfx = var.env != "" ? "-${var.env}" : ""

  secrets = {
    firebase-api-key        = "Firebase Web API key for the React SPA"
    firebase-admin-sdk-json = "Firebase Admin SDK service account JSON (Cloud Run)"
    gcp-project-id          = "GCP project ID consumed by Cloud Run at runtime"
  }
}

resource "google_secret_manager_secret" "pipeline" {
  for_each = local.secrets

  secret_id = "${each.key}${local.sfx}"

  replication {
    auto {}
  }

  labels = {
    managed = "terraform"
  }
}

# Initial placeholder versions — Cloud Run requires at least one version to exist.
# Replace firebase-api-key and firebase-admin-sdk-json with real values via:
#   gcloud secrets versions add <secret-id> --data-file=<file>
resource "google_secret_manager_secret_version" "initial" {
  for_each = local.secrets

  secret = google_secret_manager_secret.pipeline[each.key].id

  secret_data = each.key == "gcp-project-id" ? var.project_id : "PLACEHOLDER_SET_MANUALLY"

  lifecycle {
    ignore_changes = [secret_data]  # don't overwrite real values on re-apply
  }
}

# upload-api Cloud Run reads Firebase Admin SDK + project ID
resource "google_secret_manager_secret_iam_member" "upload_api_access" {
  for_each = toset(["firebase-admin-sdk-json", "gcp-project-id"])

  secret_id = google_secret_manager_secret.pipeline[each.key].id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${var.sa_upload_api_email}"
}

# validator Cloud Function reads project ID
resource "google_secret_manager_secret_iam_member" "validator_access" {
  secret_id = google_secret_manager_secret.pipeline["gcp-project-id"].id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${var.sa_validator_email}"
}

# dataflow reads project ID
resource "google_secret_manager_secret_iam_member" "dataflow_access" {
  secret_id = google_secret_manager_secret.pipeline["gcp-project-id"].id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${var.sa_dataflow_email}"
}
