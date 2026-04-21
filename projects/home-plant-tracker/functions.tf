# ── Source bucket for function zips ──────────────────────────────────────────
# This bucket stores Cloud Function source ZIPs. The ZIP itself is built and
# uploaded by the home-plant-tracker CI pipeline (not by Terraform). Terraform
# references the object by name via var.function_source_object.

resource "google_storage_bucket" "function_source" {
  name                        = "${var.project_id}-fn-source-${var.environment}"
  location                    = var.region
  storage_class               = "STANDARD"
  uniform_bucket_level_access = true
  force_destroy               = true

  labels = local.labels

  lifecycle_rule {
    condition { age = 30 }
    action { type = "Delete" }
  }

  depends_on = [google_project_service.apis]
}

# ── Service account for the function ─────────────────────────────────────────

resource "google_service_account" "plants_function" {
  account_id   = "${local.app_name}-plants-fn"
  display_name = "Plant Tracker Plants Function"
  description  = "Service account for the plants CRUD Cloud Function"
  project      = var.project_id

  depends_on = [google_project_service.apis]
}

resource "google_project_iam_member" "plants_function_firestore" {
  project = var.project_id
  role    = "roles/datastore.user"
  member  = "serviceAccount:${google_service_account.plants_function.email}"
}

resource "google_project_iam_member" "plants_function_vertexai" {
  project = var.project_id
  role    = "roles/aiplatform.user"
  member  = "serviceAccount:${google_service_account.plants_function.email}"
}

# ── Cloud Build service account permissions ──────────────────────────────────
# Cloud Functions v2 uses Cloud Build to build the function image. The Cloud Build
# service account needs permission to read the source bucket and push to Artifact Registry.

resource "google_storage_bucket_iam_member" "cloudbuild_source_reader" {
  bucket = google_storage_bucket.function_source.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${data.google_compute_default_service_account.default.email}"
}

resource "google_storage_bucket_iam_member" "gcf_agent_source_reader" {
  bucket = google_storage_bucket.function_source.name
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:service-${data.google_project.project.number}@gcf-admin-robot.iam.gserviceaccount.com"
}

resource "google_project_iam_member" "cloudbuild_artifactregistry_writer" {
  project = var.project_id
  role    = "roles/artifactregistry.writer"
  member  = "serviceAccount:${data.google_compute_default_service_account.default.email}"
}

resource "google_project_iam_member" "cloudbuild_logging" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${data.google_compute_default_service_account.default.email}"
}

resource "google_project_iam_member" "cloudbuild_storage_admin" {
  project = var.project_id
  role    = "roles/storage.admin"
  member  = "serviceAccount:${data.google_compute_default_service_account.default.email}"
}

# Cloud Functions v2 copies source to an internal gcf-v2-sources-* bucket.
# The default compute SA (used by Cloud Build) needs project-level read access
# to fetch the source during the build step.
resource "google_project_iam_member" "cloudbuild_storage_viewer" {
  project = var.project_id
  role    = "roles/storage.objectViewer"
  member  = "serviceAccount:${data.google_compute_default_service_account.default.email}"
}

# ── Cloud Function (2nd gen) ──────────────────────────────────────────────────
# The source ZIP (var.function_source_object) is built by the home-plant-tracker
# CI pipeline and uploaded to the function_source bucket before this apply runs.

resource "google_cloudfunctions2_function" "plants" {
  name        = "${local.app_name}-plants-api"
  location    = var.region
  description = "Plant Tracker CRUD API"
  project     = var.project_id

  build_config {
    runtime         = "nodejs20"
    entry_point     = "plantsApi"
    source {
      storage_source {
        bucket = google_storage_bucket.function_source.name
        object = var.function_source_object
      }
    }
  }

  service_config {
    service_account_email          = google_service_account.plants_function.email
    max_instance_count             = 5
    min_instance_count             = 0
    available_memory               = "512M"
    timeout_seconds                = 120
    ingress_settings               = "ALLOW_ALL"
    all_traffic_on_latest_revision = true

    environment_variables = {
      PROJECT_ID                          = var.project_id
      IMAGES_BUCKET                       = google_storage_bucket.images.name
      SERVICE_ACCOUNT_EMAIL               = google_service_account.plants_function.email
      BILLING_ENABLED                     = var.billing_enabled ? "true" : "false"
      BILLING_SUCCESS_URL                 = "https://${var.domain}"
      BILLING_CANCEL_URL                  = "https://${var.domain}"
      STRIPE_PRICE_HOME_PRO_MONTHLY       = var.stripe_price_home_pro_monthly
      STRIPE_PRICE_HOME_PRO_ANNUAL        = var.stripe_price_home_pro_annual
      STRIPE_PRICE_LANDSCAPER_PRO_MONTHLY = var.stripe_price_landscaper_pro_monthly
      STRIPE_PRICE_LANDSCAPER_PRO_ANNUAL  = var.stripe_price_landscaper_pro_annual
    }

    secret_environment_variables {
      key        = "GEMINI_API_KEY"
      project_id = var.project_id
      secret     = google_secret_manager_secret.gemini_api_key.secret_id
      version    = "latest"
    }

    secret_environment_variables {
      key        = "ML_ADMIN_TOKEN"
      project_id = var.project_id
      secret     = google_secret_manager_secret.ml_admin_token.secret_id
      version    = "latest"
    }

    secret_environment_variables {
      key        = "STRIPE_SECRET_KEY"
      project_id = var.project_id
      secret     = google_secret_manager_secret.stripe_secret_key.secret_id
      version    = "latest"
    }

    secret_environment_variables {
      key        = "STRIPE_WEBHOOK_SECRET"
      project_id = var.project_id
      secret     = google_secret_manager_secret.stripe_webhook_secret.secret_id
      version    = "latest"
    }
  }

  labels = local.labels

  depends_on = [
    google_project_service.apis,
    google_secret_manager_secret_iam_member.plants_function_gemini_key,
    google_secret_manager_secret_iam_member.plants_function_ml_admin_token,
    google_secret_manager_secret_iam_member.plants_function_stripe_secret_key,
    google_secret_manager_secret_iam_member.plants_function_stripe_webhook_secret,
    google_storage_bucket_iam_member.cloudbuild_source_reader,
    google_project_iam_member.cloudbuild_artifactregistry_writer,
    google_project_iam_member.cloudbuild_logging,
    google_project_iam_member.cloudbuild_storage_admin,
    google_storage_bucket_iam_member.gcf_agent_source_reader,
  ]
}

# ── Allow API Gateway's managed SA to invoke the function ────────────────────
# The API Gateway managed SA is auto-created when the API Gateway API is enabled.

resource "google_cloudfunctions2_function_iam_member" "api_gateway_invoker" {
  project        = var.project_id
  location       = var.region
  cloud_function = google_cloudfunctions2_function.plants.name
  role           = "roles/cloudfunctions.invoker"
  member         = "serviceAccount:service-${data.google_project.project.number}@gcp-sa-apigateway.iam.gserviceaccount.com"

  depends_on = [google_project_service.apis]
}

resource "google_cloud_run_v2_service_iam_member" "api_gateway_run_invoker" {
  project  = var.project_id
  location = var.region
  name     = google_cloudfunctions2_function.plants.name
  role     = "roles/run.invoker"
  member   = "serviceAccount:service-${data.google_project.project.number}@gcp-sa-apigateway.iam.gserviceaccount.com"
}

# The API Gateway signs JWTs as the plants_function SA (via backend_config.google_service_account).
# Cloud Run must accept that SA as an invoker.
resource "google_cloud_run_v2_service_iam_member" "function_sa_run_invoker" {
  project  = var.project_id
  location = var.region
  name     = google_cloudfunctions2_function.plants.name
  role     = "roles/run.invoker"
  member   = "serviceAccount:${google_service_account.plants_function.email}"
}

# Allow the function SA to sign blobs — required for generating v4 signed URLs in Cloud Run.
resource "google_service_account_iam_member" "plants_fn_self_sign" {
  service_account_id = google_service_account.plants_function.name
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = "serviceAccount:${google_service_account.plants_function.email}"
}

# Allow the API Gateway managed SA to impersonate the function SA (needed to sign JWTs for the backend).
resource "google_service_account_iam_member" "api_gateway_impersonate_fn_sa" {
  service_account_id = google_service_account.plants_function.name
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = "serviceAccount:service-${data.google_project.project.number}@gcp-sa-apigateway.iam.gserviceaccount.com"
}
