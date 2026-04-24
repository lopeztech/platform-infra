# ── Weekly retrain Cloud Run Job + Scheduler trigger (fantasy-coach#107) ─────
# Mirrors the precompute Job shape but runs ``python -m fantasy_coach retrain``
# on Monday 10:00 AEST — after Sunday's round closes and before Tuesday's
# precompute run. The Job trains a fresh XGBoost candidate, compares it to
# the incumbent on a 4-round holdout, and either:
#   - promotes (uploads candidate to gs://…-models/logistic/latest.joblib), or
#   - blocks + opens a GitHub issue tagged `model-drift`.
# Either way it always writes a drift report to Firestore
# ``model_drift_reports/{season}-{round:02d}``.

# ── Dedicated identity ───────────────────────────────────────────────────────
# Kept separate from the runtime SA (used by the API + precompute Job) so
# write access to the models bucket + GitHub PAT secret is scoped to this Job
# alone. A compromise in precompute can't overwrite model artefacts, and vice
# versa.
resource "google_service_account" "retrain" {
  account_id   = "${local.app_name}-retrain"
  display_name = "Fantasy Coach weekly retrain Job"
  description  = "Identity the retrain Cloud Run Job runs as"
  project      = var.project_id

  depends_on = [google_project_service.apis]
}

# Firestore read (matches) + write (model_drift_reports).
resource "google_project_iam_member" "retrain_firestore" {
  project = var.project_id
  role    = "roles/datastore.user"
  member  = "serviceAccount:${google_service_account.retrain.email}"
}

# GCS write on the models bucket — retrain uploads candidate artefact on
# promote. Read is included in objectAdmin so the Job can also download the
# current incumbent at startup.
resource "google_storage_bucket_iam_member" "retrain_models_admin" {
  bucket = google_storage_bucket.models.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.retrain.email}"
}

# ── GitHub PAT secret for model-drift issue creation ─────────────────────────
# Secret is created empty — the value (a fine-grained PAT with `issues: write`
# on lopeztech/fantasy-coach only) is loaded manually via `gcloud secrets
# versions add` to avoid checking PAT material into Terraform state. Absent
# value = retrain logs + skips issue creation (graceful no-op); drift report
# is still written to Firestore either way.
resource "google_secret_manager_secret" "github_model_drift_token" {
  secret_id = "github-model-drift-token"
  project   = var.project_id

  replication {
    auto {}
  }

  labels = local.labels

  depends_on = [google_project_service.apis]
}

resource "google_secret_manager_secret_iam_member" "retrain_token_access" {
  secret_id = google_secret_manager_secret.github_model_drift_token.secret_id
  project   = var.project_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.retrain.email}"
}

# Deployer SA also needs secret accessor so the CI deploy workflow's image
# rotation step (which applies env vars) can read it when mounting to the
# Job — not strictly required today (mounting is value-by-reference, resolved
# at invocation), but future env-setters may need it.

# ── Cloud Run Job ────────────────────────────────────────────────────────────
# Image rotation is handled by the app-repo deploy workflow (same pattern as
# the precompute Job). Terraform owns the Job shape; the workflow owns the
# image + env vars.
resource "google_cloud_run_v2_job" "retrain" {
  name     = "${local.app_name}-retrain"
  location = var.region
  project  = var.project_id

  template {
    template {
      service_account = google_service_account.retrain.email
      # XGBoost training on ~500 rows + shadow-eval on 4 holdout rounds fits
      # well under 5 min; 900s gives headroom for CV search on future
      # larger training sets.
      timeout     = "900s"
      max_retries = 1

      containers {
        # Placeholder — the app-repo deploy workflow rotates the image on
        # every push to main.
        image = "us-docker.pkg.dev/cloudrun/container/hello"

        # Override the API uvicorn entrypoint. `--incumbent-path` lands in
        # /tmp (writable on Cloud Run's read-only root fs); the image's
        # _ensure_model helper downloads from the GCS URI on first miss.
        command = [
          "python", "-m", "fantasy_coach", "retrain",
          "--incumbent-path", "/tmp/incumbent.joblib",
          "--candidate-path", "/tmp/candidate.joblib",
        ]

        env {
          name  = "FIREBASE_PROJECT_ID"
          value = var.project_id
        }
        env {
          name  = "STORAGE_BACKEND"
          value = "firestore"
        }
        env {
          name  = "FANTASY_COACH_MODEL_GCS_URI"
          value = "gs://${google_storage_bucket.models.name}/logistic/latest.joblib"
        }

        env {
          name = "GITHUB_MODEL_DRIFT_TOKEN"
          value_source {
            secret_key_ref {
              secret  = google_secret_manager_secret.github_model_drift_token.secret_id
              version = "latest"
            }
          }
        }

        resources {
          limits = {
            cpu = "2" # XGBoost CV benefits from a second core
            memory = "1Gi" # room for full training frame + two in-memory models
          }
        }
      }
    }
  }

  labels = local.labels

  lifecycle {
    ignore_changes = [
      # Rotated by lopeztech/fantasy-coach deploy workflow on every push.
      template[0].template[0].containers[0].image,
      # Deploy workflow may add/override env vars later (e.g. a staged model
      # path). Keep them out of TF reconciliation — same pattern as the
      # precompute Job + API service.
      template[0].template[0].containers[0].env,
      client,
      client_version,
    ]
  }

  depends_on = [
    google_project_service.apis,
    google_project_iam_member.retrain_firestore,
    google_storage_bucket_iam_member.retrain_models_admin,
    google_secret_manager_secret_iam_member.retrain_token_access,
  ]
}

# Scheduler SA already exists (iam.tf); scope its invoker to this Job too.
resource "google_cloud_run_v2_job_iam_member" "scheduler_invoker_retrain" {
  project  = var.project_id
  location = var.region
  name     = google_cloud_run_v2_job.retrain.name
  role     = "roles/run.invoker"
  member   = "serviceAccount:${google_service_account.scheduler.email}"
}

# ── Weekly schedule ──────────────────────────────────────────────────────────
# Monday 10:00 AEST — buys a full hour after Sunday night's final kickoff
# (typical last match ends ~21:00 Sun AEST) and runs before Tuesday's
# precompute Job so the live model reflects any promotion.
locals {
  retrain_run_uri = "https://run.googleapis.com/v2/projects/${var.project_id}/locations/${var.region}/jobs/${google_cloud_run_v2_job.retrain.name}:run"
}

resource "google_cloud_scheduler_job" "retrain_monday" {
  name        = "${local.app_name}-retrain-mon"
  description = "Weekly XGBoost retrain + drift detection — runs after Sunday's round closes."
  project     = var.project_id
  region      = var.region
  schedule    = "0 10 * * 1"
  time_zone   = "Australia/Sydney"

  http_target {
    uri         = local.retrain_run_uri
    http_method = "POST"

    oauth_token {
      service_account_email = google_service_account.scheduler.email
      scope                 = "https://www.googleapis.com/auth/cloud-platform"
    }
  }

  retry_config {
    # One retry is plenty — retrain is idempotent (writes replace-in-place on
    # the drift doc id, GCS object versioning preserves the prior artefact).
    retry_count          = 1
    max_retry_duration   = "0s"
    min_backoff_duration = "60s"
    max_backoff_duration = "300s"
  }

  depends_on = [
    google_project_service.apis,
    google_cloud_run_v2_job_iam_member.scheduler_invoker_retrain,
  ]
}
