# ── Precompute Cloud Run Job + Scheduler triggers (fantasy-coach#65) ─────────
# Move the cold-round scrape off the /predictions hot path. Cloud Scheduler
# fires the Job on Tue + Thu AEST; the Job shares the Cloud Run service's
# image and runs ``python -m fantasy_coach precompute`` which writes the
# round's predictions to Firestore. The API becomes a pure cache read.
#
# Image rotation: the app-repo deploy workflow updates this Job's image
# alongside the service on every push (``gcloud run jobs update``), so
# Terraform ignores image drift with ``lifecycle.ignore_changes`` — same
# pattern the Cloud Run service uses.

resource "google_cloud_run_v2_job" "precompute" {
  name     = "${local.app_name}-precompute"
  location = var.region
  project  = var.project_id

  template {
    template {
      service_account = google_service_account.runtime.email
      # One-shot per run; fail fast if the scrape takes longer than 10 min.
      # 8 fixtures × ~10s/fetch = ~80s happy-path; 600s handles slow nrl.com.
      timeout         = "600s"
      max_retries     = 1

      containers {
        # Placeholder. First real image is pushed + deployed by the app-repo
        # workflow in lopeztech/fantasy-coach; Terraform ignores image
        # drift (see lifecycle block below).
        image = "us-docker.pkg.dev/cloudrun/container/hello"

        # Override the API's uvicorn entrypoint for batch CLI use. Empty
        # args → precompute autodetects current year + next upcoming round.
        command = ["python", "-m", "fantasy_coach", "precompute"]

        env {
          name  = "FIREBASE_PROJECT_ID"
          value = var.project_id
        }
        env {
          name  = "STORAGE_BACKEND"
          value = "firestore"
        }
        # FANTASY_COACH_MODEL_PATH relies on the image baking in an artifact.
        # Today that's ``artifacts/logistic.joblib`` — the training artifact
        # shipped in the container. Swapping to an ensemble is
        # fantasy-coach#84's job; this Job inherits whatever the image ships.

        resources {
          limits = {
            cpu    = "1"
            memory = "512Mi" # gen2 floor, same as the service
          }
        }
      }
    }
  }

  labels = local.labels

  lifecycle {
    ignore_changes = [
      # app-repo deploy workflow rotates the image on every push.
      template[0].template[0].containers[0].image,
      # Deploy workflow may also set env vars (e.g. a future
      # FANTASY_COACH_MODEL_PATH switch). Keep them out of Terraform's
      # reconciliation, same as the service.
      template[0].template[0].containers[0].env,
      client,
      client_version,
    ]
  }

  depends_on = [
    google_project_service.apis,
    google_project_iam_member.runtime,
  ]
}

# Scheduler SA needs ``run.invoker`` on the Job (not project-wide) so it
# can call ``:run`` but nothing else.

resource "google_cloud_run_v2_job_iam_member" "scheduler_invoker" {
  project  = var.project_id
  location = var.region
  name     = google_cloud_run_v2_job.precompute.name
  role     = "roles/run.invoker"
  member   = "serviceAccount:${google_service_account.scheduler.email}"
}

# Two cron entries — one after the weekend to buy lead time, one on Thu
# morning to catch late team-list changes before Thu-night kickoff. Using
# the ``Australia/Sydney`` timezone lets Cloud Scheduler handle AEDT/AEST
# transitions so the cron still fires at the intended local time.

locals {
  # Cloud Run's run-a-job endpoint (v2 REST). Scheduler hits this with an
  # OAuth token minted for the scheduler SA.
  precompute_run_uri = "https://run.googleapis.com/v2/projects/${var.project_id}/locations/${var.region}/jobs/${google_cloud_run_v2_job.precompute.name}:run"
}

resource "google_cloud_scheduler_job" "precompute_tuesday" {
  name        = "${local.app_name}-precompute-tue"
  description = "Precompute next-round predictions — buys ~2 days of lead time before Thu-night kickoff."
  project     = var.project_id
  region      = var.region
  schedule    = "0 9 * * 2"
  time_zone   = "Australia/Sydney"

  http_target {
    uri         = local.precompute_run_uri
    http_method = "POST"

    oauth_token {
      service_account_email = google_service_account.scheduler.email
      scope                 = "https://www.googleapis.com/auth/cloud-platform"
    }
  }

  retry_config {
    retry_count          = 2
    max_retry_duration   = "0s"
    min_backoff_duration = "30s"
    max_backoff_duration = "300s"
  }

  depends_on = [
    google_project_service.apis,
    google_cloud_run_v2_job_iam_member.scheduler_invoker,
  ]
}

resource "google_cloud_scheduler_job" "precompute_thursday" {
  name        = "${local.app_name}-precompute-thu"
  description = "Pre-kickoff precompute — catches late team-list changes between Tue and Thu."
  project     = var.project_id
  region      = var.region
  schedule    = "0 6 * * 4"
  time_zone   = "Australia/Sydney"

  http_target {
    uri         = local.precompute_run_uri
    http_method = "POST"

    oauth_token {
      service_account_email = google_service_account.scheduler.email
      scope                 = "https://www.googleapis.com/auth/cloud-platform"
    }
  }

  retry_config {
    retry_count          = 2
    max_retry_duration   = "0s"
    min_backoff_duration = "30s"
    max_backoff_duration = "300s"
  }

  depends_on = [
    google_project_service.apis,
    google_cloud_run_v2_job_iam_member.scheduler_invoker,
  ]
}
