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
    "eventarc.googleapis.com",
    "aiplatform.googleapis.com",
    "notebooks.googleapis.com",
    "storage.googleapis.com",
    "monitoring.googleapis.com",
    "logging.googleapis.com",
    "compute.googleapis.com",
    "certificatemanager.googleapis.com",
    "billingbudgets.googleapis.com",
    "firebase.googleapis.com",
    "firebasehosting.googleapis.com",
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

  cors_origins    = ["https://${var.domain}", "http://localhost:5173"]
  upload_sa_email    = module.iam.sa_emails["upload-api"]
  validator_sa_email = module.iam.sa_emails["validator"]

  depends_on = [module.iam]
}

# ── Pub/Sub ──────────────────────────────────────────────────────────────────
module "pubsub" {
  source = "../../modules/pubsub"

  project_id      = var.project_id
  upload_sa_email = module.iam.sa_emails["upload-api"]
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

# ── Monitoring ──────────────────────────────────────────────────────────────
module "monitoring" {
  source = "../../modules/monitoring"

  project_id         = var.project_id
  notification_email = var.notification_email

  services = {
    "data-feeder" = {
      domain       = var.domain
      path         = "/"
      display_name = "Data Feeder"
    }
  }

  depends_on = [google_project_service.apis]
}

# ── Budget Alerts ──────────────────────────────────────────────────────────────

module "budget" {
  source = "../../modules/budget"

  project_id          = var.project_id
  billing_account     = var.billing_account
  monthly_budget_usd  = var.monthly_budget_usd
  notification_email  = var.notification_email

  depends_on = [google_project_service.apis]
}

# ── ML Artifacts Bucket ──────────────────────────────────────────────────────
resource "google_storage_bucket" "ml_artifacts" {
  name                        = "${var.project_id}-ml-artifacts"
  location                    = var.region
  storage_class               = "STANDARD"
  uniform_bucket_level_access = true

  labels = {
    purpose = "ml-artifacts"
    managed = "terraform"
  }

  lifecycle_rule {
    condition { age = 90 }
    action { type = "Delete" }
  }

  depends_on = [google_project_service.apis]
}

