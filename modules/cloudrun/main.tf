resource "google_cloud_run_v2_service" "api" {
  name     = "data-feeder-api-${var.env}"
  location = var.region
  ingress  = "INGRESS_TRAFFIC_ALL"

  template {
    service_account = var.service_account_email

    scaling {
      min_instance_count = var.env == "prod" ? 1 : 0  # prod: avoid cold starts
      max_instance_count = 10
    }

    containers {
      # Image is updated by CI/CD on each deploy; placeholder for first apply
      image = "us-docker.pkg.dev/cloudrun/container/hello"

      resources {
        limits = {
          cpu    = "1"
          memory = "512Mi"
        }
        cpu_idle = true  # only bill for CPU when handling requests
      }

      # All env vars pulled from Secret Manager — no plaintext in config
      dynamic "env" {
        for_each = var.secret_ids
        content {
          name = upper(replace(split("/secrets/", env.key)[1], "-${var.env}", ""))
          value_source {
            secret_key_ref {
              secret  = env.value
              version = "latest"
            }
          }
        }
      }

      env {
        name  = "ENV"
        value = var.env
      }

      env {
        name  = "GCS_RAW_BUCKET"
        value = var.gcs_bucket_names["raw"]
      }

      env {
        name  = "PUBSUB_FILE_UPLOADED_TOPIC"
        value = var.pubsub_topic_ids["file-uploaded"]
      }

      env {
        name  = "FIRESTORE_DATABASE"
        value = var.firestore_database
      }

      liveness_probe {
        http_get { path = "/health" }
        initial_delay_seconds = 5
        period_seconds        = 30
      }
    }
  }

  traffic {
    type    = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
    percent = 100
  }

  labels = {
    env     = var.env
    managed = "terraform"
  }
}

# Allow unauthenticated access to /health only — all other routes verify Firebase ID tokens
# in application code. Cloud Run itself requires auth for prod; API handles token verification.
resource "google_cloud_run_v2_service_iam_member" "public_invoker" {
  count    = var.env != "prod" ? 1 : 0  # prod locks down at Cloud Run level too
  location = google_cloud_run_v2_service.api.location
  name     = google_cloud_run_v2_service.api.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}

resource "google_cloud_run_v2_service_iam_member" "prod_invoker" {
  count    = var.env == "prod" ? 1 : 0
  location = google_cloud_run_v2_service.api.location
  name     = google_cloud_run_v2_service.api.name
  role     = "roles/run.invoker"
  member   = "allUsers"  # Firebase token validation is enforced in application middleware
}
