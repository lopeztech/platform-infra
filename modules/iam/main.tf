locals {
  sfx = var.env != "" ? "-${var.env}" : ""

  service_accounts = {
    "upload-api" = "Cloud Run API — signs GCS URLs, writes job metadata to Firestore"
    "validator"  = "Cloud Function — reads Bronze, writes Silver & Rejected, updates Firestore"
    "dataflow"   = "Dataflow workers — reads Silver, writes BigQuery Gold, updates Firestore"
    "ml-pipeline" = "ML pipelines — trains models on Vertex AI, reads BigQuery, writes GCS artifacts"
    "cicd"       = "GitHub Actions via Workload Identity — deploys Cloud Run & Cloud Functions"
  }
}

resource "google_service_account" "pipeline" {
  for_each = local.service_accounts

  account_id   = "sa-${each.key}${local.sfx}"
  display_name = each.key
  description  = each.value
  project      = var.project_id
}

# ── upload-api ──────────────────────────────────────────────────────────────
# Signs GCS URLs scoped to Bronze bucket; reads/writes Firestore jobs collection
resource "google_project_iam_member" "upload_api_token_creator" {
  project = var.project_id
  role    = "roles/iam.serviceAccountTokenCreator"
  member  = "serviceAccount:${google_service_account.pipeline["upload-api"].email}"
}

resource "google_project_iam_member" "upload_api_firestore" {
  project = var.project_id
  role    = "roles/datastore.user"
  member  = "serviceAccount:${google_service_account.pipeline["upload-api"].email}"
}

resource "google_project_iam_member" "upload_api_secret_accessor" {
  project = var.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${google_service_account.pipeline["upload-api"].email}"
}

resource "google_project_iam_member" "upload_api_storage_viewer" {
  project = var.project_id
  role    = "roles/storage.objectViewer"
  member  = "serviceAccount:${google_service_account.pipeline["upload-api"].email}"
}

resource "google_project_iam_member" "upload_api_bq_viewer" {
  project = var.project_id
  role    = "roles/bigquery.dataViewer"
  member  = "serviceAccount:${google_service_account.pipeline["upload-api"].email}"
}

resource "google_project_iam_member" "upload_api_bq_job_user" {
  project = var.project_id
  role    = "roles/bigquery.jobUser"
  member  = "serviceAccount:${google_service_account.pipeline["upload-api"].email}"
}

# ── validator ───────────────────────────────────────────────────────────────
resource "google_project_iam_member" "validator_firestore" {
  project = var.project_id
  role    = "roles/datastore.user"
  member  = "serviceAccount:${google_service_account.pipeline["validator"].email}"
}

resource "google_project_iam_member" "validator_pubsub_subscriber" {
  project = var.project_id
  role    = "roles/pubsub.subscriber"
  member  = "serviceAccount:${google_service_account.pipeline["validator"].email}"
}

resource "google_project_iam_member" "validator_pubsub_publisher" {
  project = var.project_id
  role    = "roles/pubsub.publisher"
  member  = "serviceAccount:${google_service_account.pipeline["validator"].email}"
}

resource "google_project_iam_member" "validator_log_writer" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.pipeline["validator"].email}"
}

resource "google_project_iam_member" "validator_storage_viewer" {
  project = var.project_id
  role    = "roles/storage.objectViewer"
  member  = "serviceAccount:${google_service_account.pipeline["validator"].email}"
}

resource "google_project_iam_member" "validator_storage_creator" {
  project = var.project_id
  role    = "roles/storage.objectCreator"
  member  = "serviceAccount:${google_service_account.pipeline["validator"].email}"
}

resource "google_project_iam_member" "validator_eventarc_receiver" {
  project = var.project_id
  role    = "roles/eventarc.eventReceiver"
  member  = "serviceAccount:${google_service_account.pipeline["validator"].email}"
}

# ── dataflow ─────────────────────────────────────────────────────────────────
resource "google_project_iam_member" "dataflow_storage_viewer" {
  project = var.project_id
  role    = "roles/storage.objectViewer"
  member  = "serviceAccount:${google_service_account.pipeline["dataflow"].email}"
}

resource "google_project_iam_member" "dataflow_worker" {
  project = var.project_id
  role    = "roles/dataflow.worker"
  member  = "serviceAccount:${google_service_account.pipeline["dataflow"].email}"
}

resource "google_project_iam_member" "dataflow_bq_editor" {
  project = var.project_id
  role    = "roles/bigquery.dataEditor"
  member  = "serviceAccount:${google_service_account.pipeline["dataflow"].email}"
}

resource "google_project_iam_member" "dataflow_bq_job_user" {
  project = var.project_id
  role    = "roles/bigquery.jobUser"
  member  = "serviceAccount:${google_service_account.pipeline["dataflow"].email}"
}

resource "google_project_iam_member" "dataflow_firestore" {
  project = var.project_id
  role    = "roles/datastore.user"
  member  = "serviceAccount:${google_service_account.pipeline["dataflow"].email}"
}

resource "google_project_iam_member" "dataflow_pubsub_subscriber" {
  project = var.project_id
  role    = "roles/pubsub.subscriber"
  member  = "serviceAccount:${google_service_account.pipeline["dataflow"].email}"
}

resource "google_project_iam_member" "dataflow_pubsub_publisher" {
  project = var.project_id
  role    = "roles/pubsub.publisher"
  member  = "serviceAccount:${google_service_account.pipeline["dataflow"].email}"
}

# ── ml (Vertex AI pipelines) ─────────────────────────────────────────────────
resource "google_project_iam_member" "ml_aiplatform_user" {
  project = var.project_id
  role    = "roles/aiplatform.user"
  member  = "serviceAccount:${google_service_account.pipeline["ml-pipeline"].email}"
}

resource "google_project_iam_member" "ml_bq_viewer" {
  project = var.project_id
  role    = "roles/bigquery.dataViewer"
  member  = "serviceAccount:${google_service_account.pipeline["ml-pipeline"].email}"
}

resource "google_project_iam_member" "ml_bq_job_user" {
  project = var.project_id
  role    = "roles/bigquery.jobUser"
  member  = "serviceAccount:${google_service_account.pipeline["ml-pipeline"].email}"
}

resource "google_project_iam_member" "ml_storage_admin" {
  project = var.project_id
  role    = "roles/storage.objectAdmin"
  member  = "serviceAccount:${google_service_account.pipeline["ml-pipeline"].email}"
}

resource "google_project_iam_member" "ml_ar_reader" {
  project = var.project_id
  role    = "roles/artifactregistry.reader"
  member  = "serviceAccount:${google_service_account.pipeline["ml-pipeline"].email}"
}

resource "google_project_iam_member" "ml_bq_data_editor" {
  project = var.project_id
  role    = "roles/bigquery.dataEditor"
  member  = "serviceAccount:${google_service_account.pipeline["ml-pipeline"].email}"
}

# ── cicd (GitHub Actions via Workload Identity Federation) ───────────────────
resource "google_project_iam_member" "cicd_run_admin" {
  project = var.project_id
  role    = "roles/run.admin"
  member  = "serviceAccount:${google_service_account.pipeline["cicd"].email}"
}

resource "google_project_iam_member" "cicd_functions_admin" {
  project = var.project_id
  role    = "roles/cloudfunctions.admin"
  member  = "serviceAccount:${google_service_account.pipeline["cicd"].email}"
}

resource "google_project_iam_member" "cicd_aiplatform_user" {
  project = var.project_id
  role    = "roles/aiplatform.user"
  member  = "serviceAccount:${google_service_account.pipeline["cicd"].email}"
}

resource "google_project_iam_member" "cicd_artifact_writer" {
  project = var.project_id
  role    = "roles/artifactregistry.writer"
  member  = "serviceAccount:${google_service_account.pipeline["cicd"].email}"
}

resource "google_project_iam_member" "cicd_sa_user" {
  project = var.project_id
  role    = "roles/iam.serviceAccountUser"
  member  = "serviceAccount:${google_service_account.pipeline["cicd"].email}"
}

# ── Workload Identity Federation for GitHub Actions ───────────────────────────
resource "google_iam_workload_identity_pool" "github" {
  workload_identity_pool_id = "github-pool${local.sfx}"
  display_name              = "GitHub Actions"
  description               = "WIF pool for GitHub Actions — no static keys"
}

resource "google_iam_workload_identity_pool_provider" "github_oidc" {
  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = "github-oidc${local.sfx}"
  display_name                       = "GitHub OIDC"

  attribute_mapping = {
    "google.subject"       = "assertion.sub"
    "attribute.actor"      = "assertion.actor"
    "attribute.repository" = "assertion.repository"
  }

  attribute_condition = join(" || ", [
    for repo in concat([var.github_repo], var.github_repos_allowed) :
    "attribute.repository == \"${var.github_org}/${repo}\""
  ])

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

resource "google_service_account_iam_member" "cicd_wif_binding" {
  service_account_id = google_service_account.pipeline["cicd"].name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.repository/${var.github_org}/${var.github_repo}"
}

resource "google_service_account_iam_member" "cicd_wif_binding_extra" {
  for_each = toset(var.github_repos_allowed)

  service_account_id = google_service_account.pipeline["cicd"].name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.repository/${var.github_org}/${each.value}"
}
