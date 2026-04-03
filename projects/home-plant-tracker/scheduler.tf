# ── Cloud Scheduler: weekly ML data export ───────────────────────────────────
# Triggers GET /ml/export on the Cloud Function every Sunday at 3 AM AEST.
# The endpoint is admin-gated via x-admin-token header.

resource "google_cloud_scheduler_job" "ml_export_weekly" {
  name        = "${local.app_name}-ml-export-weekly"
  description = "Weekly ML training data export from plant care history"
  project     = var.project_id
  region      = var.region
  schedule    = "0 3 * * 0"
  time_zone   = "Australia/Sydney"

  http_target {
    uri         = "${google_cloudfunctions2_function.plants.service_config[0].uri}/ml/export"
    http_method = "GET"
    headers = {
      "x-admin-token" = var.ml_admin_token
    }

    oidc_token {
      service_account_email = google_service_account.plants_function.email
      audience              = google_cloudfunctions2_function.plants.service_config[0].uri
    }
  }

  retry_config {
    retry_count          = 1
    max_retry_duration   = "0s"
    min_backoff_duration = "5s"
    max_backoff_duration = "60s"
  }

  depends_on = [google_project_service.apis]
}
