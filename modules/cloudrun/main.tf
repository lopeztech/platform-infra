locals {
  sfx = var.env != "" ? "-${var.env}" : ""
}

resource "google_cloud_run_v2_service" "api" {
  name     = "data-feeder-api${local.sfx}"
  location = var.region
  ingress  = "INGRESS_TRAFFIC_ALL"

  template {
    service_account = var.service_account_email

    scaling {
      min_instance_count = 0  # scale to zero when idle
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
          name = upper(replace(env.key, "-", "_"))
          value_source {
            secret_key_ref {
              secret  = env.value
              version = "latest"
            }
          }
        }
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
  }

  traffic {
    type    = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
    percent = 100
  }

  labels = {
    managed = "terraform"
  }

  lifecycle {
    ignore_changes = [
      template[0].containers[0].image,
      client,
      client_version,
    ]
  }
}

# Note: allUsers Cloud Run invoker is blocked by org policy constraints/iam.allowedPolicyMemberDomains.
# To allow public access, either update the org policy or configure IAP on the load balancer.
# resource "google_cloud_run_v2_service_iam_member" "public_invoker" { ... }
