# ── Artifact Registry ─────────────────────────────────────────────────────────

resource "google_artifact_registry_repository" "app" {
  location      = var.region
  repository_id = "${local.app_name}-images"
  description   = "Docker images for SRE Monitor API"
  format        = "DOCKER"
  project       = var.project_id

  depends_on = [google_project_service.apis]
}

resource "google_artifact_registry_repository_iam_member" "deployer_writer" {
  location   = google_artifact_registry_repository.app.location
  repository = google_artifact_registry_repository.app.name
  role       = "roles/artifactregistry.writer"
  member     = "serviceAccount:${google_service_account.github_deployer.email}"
  project    = var.project_id
}

# ── Cloud Run — API backend ───────────────────────────────────────────────────
# Serves /api/* requests. The frontend is served separately from GCS via CDN.
# Placeholder image used until CI deploys the real image.

resource "google_cloud_run_v2_service" "app" {
  name     = local.app_name
  location = var.region
  project  = var.project_id
  ingress  = "INGRESS_TRAFFIC_ALL"

  template {
    containers {
      image = "us-docker.pkg.dev/cloudrun/container/hello"
      ports {
        container_port = 8080
      }
      resources {
        limits = {
          cpu    = "1"
          memory = "512Mi"
        }
      }

      # Auth secrets from Secret Manager
      env {
        name = "JWT_SECRET"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.jwt_secret.secret_id
            version = "latest"
          }
        }
      }
      env {
        name = "GITHUB_OAUTH_CLIENT_ID"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.github_oauth_client_id.secret_id
            version = "latest"
          }
        }
      }
      env {
        name = "GITHUB_OAUTH_CLIENT_SECRET"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.github_oauth_client_secret.secret_id
            version = "latest"
          }
        }
      }

      # GCP billing export configuration for cost monitoring
      env {
        name  = "GCP_BILLING_PROJECT_ID"
        value = var.project_id
      }
      env {
        name  = "GCP_BILLING_DATASET"
        value = "billing_export"
      }
      env {
        name  = "GCP_BILLING_TABLE"
        value = var.gcp_billing_table
      }

      startup_probe {
        http_get { path = "/health" }
        initial_delay_seconds = 0
        period_seconds        = 10
        failure_threshold     = 3
        timeout_seconds       = 3
      }

      liveness_probe {
        http_get { path = "/health" }
        initial_delay_seconds = 5
        period_seconds        = 30
      }
    }
    scaling {
      min_instance_count = 0
      max_instance_count = 3
    }
  }

  lifecycle {
    ignore_changes = [
      template[0].containers[0].image,
      client,
      client_version,
    ]
  }

  depends_on = [google_project_service.apis]
}

