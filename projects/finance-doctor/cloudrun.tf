# ── Artifact Registry ─────────────────────────────────────────────────────────

resource "google_artifact_registry_repository" "app" {
  location      = var.region
  repository_id = "${local.app_name}-images"
  description   = "Docker images for Finance Doctor"
  format        = "DOCKER"
  project       = var.project_id
  labels        = local.labels

  depends_on = [google_project_service.apis]
}

resource "google_artifact_registry_repository_iam_member" "deployer_writer" {
  location   = google_artifact_registry_repository.app.location
  repository = google_artifact_registry_repository.app.name
  role       = "roles/artifactregistry.writer"
  member     = "serviceAccount:${google_service_account.github_deployer.email}"
  project    = var.project_id
}

# ── Cloud Run ─────────────────────────────────────────────────────────────────
# Public ingress, no load balancer — most cost-effective for a Next.js app.
# Domain mapping provides free Google-managed SSL.
# Scale-to-zero means you only pay when handling requests.

resource "google_cloud_run_v2_service" "app" {
  name     = local.app_name
  location = var.region
  project  = var.project_id
  ingress  = "INGRESS_TRAFFIC_ALL"

  template {
    service_account = google_service_account.app_runtime.email

    containers {
      image = "us-docker.pkg.dev/cloudrun/container/hello"
      ports {
        container_port = 3000
      }
      resources {
        limits = {
          cpu    = "1"
          memory = "512Mi"
        }
        cpu_idle          = true  # only bill for CPU when handling requests
        startup_cpu_boost = true  # faster cold starts
      }

      env {
        name = "GOOGLE_CLIENT_ID"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.google_client_id.secret_id
            version = "latest"
          }
        }
      }

      env {
        name = "GOOGLE_CLIENT_SECRET"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.google_client_secret.secret_id
            version = "latest"
          }
        }
      }

      env {
        name = "AUTH_SECRET"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.auth_secret.secret_id
            version = "latest"
          }
        }
      }

      env {
        name  = "AUTH_URL"
        value = "https://finance-doctor-ws5d6symma-ts.a.run.app"
      }
    }

    scaling {
      min_instance_count = 0   # scale to zero — pay nothing when idle
      max_instance_count = 3
    }
  }

  traffic {
    type    = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
    percent = 100
  }

  labels = local.labels

  lifecycle {
    ignore_changes = [
      template[0].containers[0].image,
      client,
      client_version,
    ]
  }

  depends_on = [google_project_service.apis]
}

# Public access is configured via gcloud CLI (--allow-unauthenticated) since
# the Terraform allUsers binding is blocked by org policy.
# Run once after first deploy:
#   gcloud run services set-iam-policy finance-doctor --region=australia-southeast1 \
#     --project=finance-doctor-lcd policy.yaml
#
# Or use: gcloud run deploy finance-doctor --allow-unauthenticated ...

# ── App Runtime Service Account ───────────────────────────────────────────────

resource "google_service_account" "app_runtime" {
  account_id   = "${local.app_name}-runtime"
  display_name = "Finance Doctor Cloud Run Runtime"
  description  = "Service account for the Finance Doctor Cloud Run service"
  project      = var.project_id

  depends_on = [google_project_service.apis]
}

resource "google_project_iam_member" "app_runtime_secret_accessor" {
  project = var.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${google_service_account.app_runtime.email}"
}
