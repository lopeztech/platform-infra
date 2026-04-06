# ── BigQuery — Billing Export ─────────────────────────────────────────────────
# Stores GCP billing export data queried by the SRE Monitor costs API.
# Billing export itself is configured via Console (Billing > Billing export).

resource "google_bigquery_dataset" "billing_export" {
  dataset_id    = "billing_export"
  friendly_name = "Billing Export"
  description   = "Cloud billing export for SRE Monitor cost analysis"
  location      = var.region
  project       = var.project_id

  labels = local.labels

  depends_on = [google_project_service.apis]
}

# Grant the Cloud Run default SA read access to the billing dataset
resource "google_bigquery_dataset_iam_member" "cloudrun_billing_reader" {
  dataset_id = google_bigquery_dataset.billing_export.dataset_id
  role       = "roles/bigquery.dataViewer"
  member     = "serviceAccount:${data.google_compute_default_service_account.default.email}"
  project    = var.project_id
}
