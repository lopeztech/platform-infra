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
  ingress  = "INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER"

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

# Note: allUsers Cloud Run invoker is blocked by org policy constraints/iam.allowedPolicyMemberDomains.
# To allow public access via the load balancer, either update the org policy or configure IAP
# on the backend service and grant roles/run.invoker to the IAP service account instead.
# resource "google_cloud_run_v2_service_iam_member" "lb_invoker" { ... }

# Serverless NEG — connects the Load Balancer to Cloud Run
resource "google_compute_region_network_endpoint_group" "app" {
  name                  = "${local.app_name}-neg-${var.environment}"
  network_endpoint_type = "SERVERLESS"
  region                = var.region
  project               = var.project_id

  cloud_run {
    service = google_cloud_run_v2_service.app.name
  }

  depends_on = [google_project_service.apis]
}
