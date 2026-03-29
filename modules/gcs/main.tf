locals {
  sfx = var.env != "" ? "-${var.env}" : ""

  layers = {
    raw = {
      description     = "Bronze zone — immutable raw uploads"
      retention_days  = 90
      versioning      = true   # immutable source of truth
      kms_key         = var.kms_key_ids["raw"]
    }
    staging = {
      description     = "Silver zone — validated, type-cast Parquet"
      retention_days  = 30
      versioning      = false
      kms_key         = var.kms_key_ids["staging"]
    }
    curated = {
      description     = "Gold zone — business-ready aggregated data"
      retention_days  = null  # indefinite
      versioning      = false
      kms_key         = var.kms_key_ids["curated"]
    }
    rejected = {
      description     = "Quarantine — failed validation records with error annotations"
      retention_days  = 14
      versioning      = false
      kms_key         = var.kms_key_ids["rejected"]
    }
  }
}

# Grant GCS service agent permission to use each KMS key for CMEK encryption
resource "google_kms_crypto_key_iam_member" "gcs_encrypter_decrypter" {
  for_each = local.layers

  crypto_key_id = each.value.kms_key
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:${data.google_storage_project_service_account.gcs_sa.email_address}"
}

resource "google_storage_bucket" "medallion" {
  for_each = local.layers

  name                        = "${var.project_id}-${each.key}${local.sfx}"
  location                    = var.region
  storage_class               = "STANDARD"
  uniform_bucket_level_access = true  # no per-object ACLs
  public_access_prevention    = "enforced"

  versioning {
    enabled = each.value.versioning
  }

  dynamic "lifecycle_rule" {
    for_each = each.value.retention_days != null ? [each.value.retention_days] : []
    content {
      action { type = "Delete" }
      condition { age = lifecycle_rule.value }
    }
  }

  dynamic "cors" {
    for_each = each.key == "raw" && length(var.cors_origins) > 0 ? [1] : []
    content {
      origin          = var.cors_origins
      method          = ["GET", "HEAD", "PUT", "OPTIONS"]
      response_header = ["Content-Type", "Content-Range", "Content-Length", "ETag", "x-goog-*"]
      max_age_seconds = 3600
    }
  }

  encryption {
    default_kms_key_name = each.value.kms_key
  }

  labels = {
    layer   = each.key
    project = var.project_id
    managed = "terraform"
  }

  depends_on = [google_kms_crypto_key_iam_member.gcs_encrypter_decrypter]
}

# Upload API service account needs read/write access to the raw bucket
resource "google_storage_bucket_iam_member" "upload_api_raw" {
  count  = var.upload_sa_email != "" ? 1 : 0
  bucket = google_storage_bucket.medallion["raw"].name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${var.upload_sa_email}"
}

# Notify Pub/Sub when a new object lands in the Bronze (raw) bucket
resource "google_storage_notification" "bronze_finalize" {
  bucket         = google_storage_bucket.medallion["raw"].name
  payload_format = "JSON_API_V1"
  topic          = var.pubsub_topic_id
  event_types    = ["OBJECT_FINALIZE"]

  depends_on = [google_pubsub_topic_iam_member.gcs_publisher]
}

# GCS service agent needs publish rights on the file-uploaded topic
data "google_storage_project_service_account" "gcs_sa" {
  project = var.project_id
}

resource "google_pubsub_topic_iam_member" "gcs_publisher" {
  topic  = var.pubsub_topic_id
  role   = "roles/pubsub.publisher"
  member = "serviceAccount:${data.google_storage_project_service_account.gcs_sa.email_address}"
}
