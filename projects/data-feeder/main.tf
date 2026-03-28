terraform {
  required_version = ">= 1.6"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 5.0"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
  }

  backend "gcs" {
    # Populated at init time:
    #   terraform init \
    #     -backend-config="bucket=platform-infra-lcd-tf-state" \
    #     -backend-config="prefix=terraform/state/data-feeder"
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

provider "google-beta" {
  project = var.project_id
  region  = var.region
}

# ── APIs ─────────────────────────────────────────────────────────────────────
resource "google_project_service" "apis" {
  for_each = toset([
    "iam.googleapis.com",
    "iamcredentials.googleapis.com",
    "sts.googleapis.com",
    "secretmanager.googleapis.com",
    "cloudkms.googleapis.com",
    "pubsub.googleapis.com",
    "bigquery.googleapis.com",
    "firestore.googleapis.com",
    "run.googleapis.com",
    "cloudfunctions.googleapis.com",
    "cloudbuild.googleapis.com",
    "artifactregistry.googleapis.com",
    "dataflow.googleapis.com",
    "storage.googleapis.com",
    "monitoring.googleapis.com",
    "logging.googleapis.com",
  ])

  service            = each.value
  disable_on_destroy = false
}

# ── KMS keys (CMEK) ─────────────────────────────────────────────────────────
resource "google_kms_key_ring" "data_pipeline" {
  name     = "data-pipeline"
  location = var.region

  depends_on = [google_project_service.apis]
}

resource "google_kms_crypto_key" "layers" {
  for_each = toset(["bronze", "silver", "gold", "firestore", "bigquery"])

  name            = "key-${each.key}"
  key_ring        = google_kms_key_ring.data_pipeline.id
  rotation_period = "7776000s" # 90 days

  lifecycle {
    prevent_destroy = true
  }
}

# ── IAM ──────────────────────────────────────────────────────────────────────
module "iam" {
  source = "../../modules/iam"

  project_id           = var.project_id
  github_repos_allowed = ["data-feeder"]
}

# ── GCS ──────────────────────────────────────────────────────────────────────
module "gcs" {
  source = "../../modules/gcs"

  project_id      = var.project_id
  region          = var.region
  pubsub_topic_id = module.pubsub.topic_ids["file-uploaded"]

  kms_key_ids = {
    raw      = google_kms_crypto_key.layers["bronze"].id
    staging  = google_kms_crypto_key.layers["silver"].id
    curated  = google_kms_crypto_key.layers["gold"].id
    rejected = google_kms_crypto_key.layers["bronze"].id
  }

  depends_on = [module.iam]
}

# ── Pub/Sub ──────────────────────────────────────────────────────────────────
module "pubsub" {
  source = "../../modules/pubsub"

  project_id = var.project_id
}

# ── BigQuery ─────────────────────────────────────────────────────────────────
module "bigquery" {
  source = "../../modules/bigquery"

  project_id = var.project_id
  region     = var.region
  kms_key_id = google_kms_crypto_key.layers["bigquery"].id
}

# ── Firestore ─────────────────────────────────────────────────────────────────
module "firestore" {
  source = "../../modules/firestore"

  project_id = var.project_id
  region     = var.region
}

# ── Secret Manager ────────────────────────────────────────────────────────────
module "secrets" {
  source = "../../modules/secretmanager"

  project_id          = var.project_id
  sa_upload_api_email = module.iam.sa_emails["upload-api"]
  sa_validator_email  = module.iam.sa_emails["validator"]
  sa_dataflow_email   = module.iam.sa_emails["dataflow"]
}

# ── Cloud Run ────────────────────────────────────────────────────────────────
module "cloudrun" {
  source = "../../modules/cloudrun"

  project_id            = var.project_id
  region                = var.region
  service_account_email = module.iam.sa_emails["upload-api"]
  secret_ids            = module.secrets.secret_ids
  gcs_bucket_names      = module.gcs.bucket_names
  pubsub_topic_ids      = module.pubsub.topic_ids
  firestore_database    = module.firestore.database_name
}

# Cloud Run domain mapping is not supported in australia-southeast1.
# Use the Cloud Run service URL directly, or add a global LB if a custom
# domain is needed.

# ── Artifact Registry ────────────────────────────────────────────────────────
resource "google_artifact_registry_repository" "app" {
  location      = var.region
  repository_id = "data-feeder-images"
  description   = "Docker images for Data Feeder"
  format        = "DOCKER"
  project       = var.project_id

  depends_on = [google_project_service.apis]
}
