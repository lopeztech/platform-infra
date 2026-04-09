# ── Images bucket ─────────────────────────────────────────────────────────────
# Stores user-uploaded floorplan images and plant photos.
# Objects are uploaded directly from the browser via signed PUT URLs.
# Objects are NOT public — the API signs time-limited read URLs (1 h) on demand.

resource "google_storage_bucket" "images" {
  name                        = "${var.project_id}-${local.app_name}-images-${var.environment}"
  location                    = var.region
  storage_class               = "STANDARD"
  uniform_bucket_level_access = true
  force_destroy               = false

  labels = local.labels

  cors {
    origin          = ["https://${var.domain}", "http://localhost:5173"]
    method          = ["GET", "HEAD", "PUT", "OPTIONS"]
    response_header = ["Content-Type", "ETag"]
    max_age_seconds = 3600
  }

  depends_on = [google_project_service.apis]
}

resource "google_storage_bucket_iam_member" "function_sa_images_object_admin" {
  bucket = google_storage_bucket.images.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.plants_function.email}"
}

# ── ML data export bucket ────────────────────────────────────────────────────
# Stores NDJSON feature tables exported by GET /ml/export for Vertex AI training.

resource "google_storage_bucket" "ml_data" {
  name                        = "${var.project_id}-${local.app_name}-ml-data-${var.environment}"
  location                    = var.region
  storage_class               = "STANDARD"
  uniform_bucket_level_access = true
  force_destroy               = false

  labels = local.labels

  lifecycle_rule {
    condition { age = 90 }
    action { type = "Delete" }
  }

  depends_on = [google_project_service.apis]
}

resource "google_storage_bucket_iam_member" "function_sa_ml_data_writer" {
  bucket = google_storage_bucket.ml_data.name
  role   = "roles/storage.objectCreator"
  member = "serviceAccount:${google_service_account.plants_function.email}"
}
