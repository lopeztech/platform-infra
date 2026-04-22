# ── Artifact Registry ────────────────────────────────────────────────────────

resource "google_artifact_registry_repository" "app" {
  location      = var.region
  repository_id = local.app_name
  description   = "Fantasy Coach API Docker images"
  format        = "DOCKER"
  project       = var.project_id

  labels     = local.labels
  depends_on = [google_project_service.apis]
}

# Deployer already has project-wide roles/artifactregistry.writer via iam.tf,
# so no per-repo grant is needed. (Explicit repo-level grant left out to
# avoid double-binding.)

# ── Cloud Run ────────────────────────────────────────────────────────────────
# Scale-to-zero, CPU throttled (idle cost ≈ $0). Image is managed by the
# lopeztech/fantasy-coach deploy workflow; terraform creates the service
# with a placeholder image and then ignores it on future plans.

resource "google_cloud_run_v2_service" "api" {
  name     = "${local.app_name}-api"
  location = var.region
  ingress  = "INGRESS_TRAFFIC_ALL"
  project  = var.project_id

  template {
    service_account = google_service_account.runtime.email

    scaling {
      min_instance_count = 0
      max_instance_count = 2
    }

    # Right-sized from Cloud Run's 300s default after 13h of post-launch
    # metrics. Cold-round scrape does ~8 sequential nrl.com fetches, so
    # 60s is unsafe until fantasy-coach#65 lands and scrape is off-path —
    # 120s keeps headroom while still cutting 60% off the default.
    timeout = "120s"

    # Pinned at Cloud Run's default (80). Explicit so TF and the
    # app-repo deploy workflow can't silently drift apart. Candidate to
    # revisit (80 → 200) after 30 days of real traffic on what is
    # mostly an I/O endpoint.
    max_instance_request_concurrency = 80

    containers {
      # Placeholder. First real image is pushed + deployed by the app-repo
      # workflow in lopeztech/fantasy-coach; terraform ignores image drift
      # (see lifecycle block below).
      image = "us-docker.pkg.dev/cloudrun/container/hello"

      ports {
        container_port = 8080
      }

      resources {
        limits = {
          cpu = "1"
          # gen2 execution environment has a 512Mi minimum enforced by
          # `gcloud run deploy`. The Cloud Run API accepts smaller values
          # so a bare `terraform apply` can set 256Mi successfully, but
          # every subsequent app-repo deploy then fails. Keep at 512Mi to
          # stay in sync with the deploy workflow; dropping below would
          # require switching execution_environment to gen1, which costs
          # us startup-cpu-boost + the newer networking stack.
          memory = "512Mi"
        }
        cpu_idle          = true # throttle CPU when not serving a request
        startup_cpu_boost = true # briefly lift the throttle on cold start
      }

      startup_probe {
        http_get { path = "/healthz" }
        initial_delay_seconds = 0
        period_seconds        = 5
        failure_threshold     = 5
        timeout_seconds       = 3
      }

      liveness_probe {
        http_get { path = "/healthz" }
        initial_delay_seconds = 10
        period_seconds        = 30
      }
    }
  }

  traffic {
    type    = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
    percent = 100
  }

  labels = local.labels

  lifecycle {
    ignore_changes = [
      # The app-repo deploy workflow rotates the image. Terraform shouldn't
      # churn it back to the placeholder on the next plan.
      template[0].containers[0].image,
      # The deploy workflow sets runtime env vars (FIREBASE_PROJECT_ID,
      # STORAGE_BACKEND once #15 lands, etc.) via `gcloud run deploy
      # --set-env-vars`. Terraform must not reconcile them back to empty on
      # apply — that would silently disable FirebaseAuthMiddleware and leave
      # /predictions open. The deploy workflow is the source of truth.
      template[0].containers[0].env,
      # `client` / `client_version` are set by `gcloud run deploy` and would
      # otherwise show as cosmetic drift on every apply.
      client,
      client_version,
    ]
  }

  depends_on = [
    google_project_service.apis,
    google_project_iam_member.deployer,
  ]
}

# ── Public-access binding for the Cloud Run API ──────────────────────────────
# The SPA at fantasy.lopezcloud.dev calls this service directly from the
# browser. Browsers can't mint Google-signed OAuth2 ID tokens, so Cloud Run's
# IAM layer can't gate the request — auth happens one level in, at
# FirebaseAuthMiddleware (src/fantasy_coach/auth.py), which rejects any
# non-/healthz request missing a valid Firebase ID token with 401.
#
# ── One-time manual bootstrap (per project) ──────────────────────────────────
# The organisation's iam.allowedPolicyMemberDomains constraint blocks
# allUsers bindings by default. Override it once at the project level with
# an org admin's own credentials — roles/orgpolicy.policyAdmin isn't
# grantable at the project level, so neither terraform nor the deployer SA
# can apply it:
#
#   cat > /tmp/allow-public.yaml <<'EOF'
#   name: projects/fantasy-coach-lcd/policies/iam.allowedPolicyMemberDomains
#   spec:
#     rules:
#     - allowAll: true
#   EOF
#   gcloud org-policies set-policy /tmp/allow-public.yaml
#
# Once the constraint is lifted, terraform owns the binding below. Same
# pattern as finance-doctor's functions_public_access.tf.
resource "google_cloud_run_v2_service_iam_member" "public_invoker" {
  project  = var.project_id
  location = var.region
  name     = google_cloud_run_v2_service.api.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}
