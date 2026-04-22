# ── Model artifact bucket (fantasy-coach#93) ─────────────────────────────────
# Holds trained model artefacts (``.joblib`` blobs) for the Cloud Run
# precompute Job to download at startup. Decouples model lifecycle from
# image build/deploy: retraining uploads a new object; no image rebuild.
#
# One blob is read at runtime — ``logistic/latest.joblib`` — by
# ``fantasy_coach.predictions._ensure_model`` on a cache-miss path. Versioning
# keeps prior objects around so a bad upload can be rolled back with
# ``gcloud storage cp`` (copy the previous generation back on top of latest).
#
# Access model: only the runtime SA reads the bucket (``objectViewer``).
# Uploads are manual from a developer laptop today (see issue #93 option 3);
# an automated trainer with upload rights is a future issue.

resource "google_storage_bucket" "models" {
  name     = "${var.project_id}-models"
  location = var.region
  project  = var.project_id

  storage_class               = "STANDARD"
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"

  # Keep prior generations so a bad artefact can be rolled back without
  # re-training. 30-day noncurrent cleanup keeps the bill flat.
  versioning {
    enabled = true
  }

  lifecycle_rule {
    action {
      type = "Delete"
    }
    condition {
      with_state                 = "NONCURRENT"
      num_newer_versions         = 5
      days_since_noncurrent_time = 30
    }
  }

  labels = local.labels

  depends_on = [google_project_service.apis]
}

# Runtime SA needs to read artefacts at container startup. Service-level
# grant keeps the blast radius to this one bucket.
resource "google_storage_bucket_iam_member" "runtime_model_reader" {
  bucket = google_storage_bucket.models.name
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${google_service_account.runtime.email}"
}
