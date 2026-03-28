locals {
  sfx = var.env != "" ? "_${var.env}" : ""  # BigQuery uses underscores in dataset IDs

  datasets = {
    raw = {
      description          = "External tables over Bronze GCS — schema-on-read, no load required"
      default_table_expiry = null
    }
    staging = {
      description          = "Silver layer — validated, type-cast native tables"
      default_table_expiry = 5184000000 # 60 days in ms
    }
    curated = {
      description          = "Gold layer — aggregated, business-ready analytics tables"
      default_table_expiry = null
    }
    audit = {
      description          = "Pipeline audit logs, data quality reports, dataset version history"
      default_table_expiry = null
    }
  }
}

# BigQuery managed encryption service account needs permission to use the KMS key
data "google_project" "project" {
  project_id = var.project_id
}

resource "google_kms_crypto_key_iam_member" "bq_encrypter_decrypter" {
  crypto_key_id = var.kms_key_id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:bq-${data.google_project.project.number}@bigquery-encryption.iam.gserviceaccount.com"
}

resource "google_bigquery_dataset" "pipeline" {
  for_each = local.datasets

  depends_on = [google_kms_crypto_key_iam_member.bq_encrypter_decrypter]

  dataset_id                  = "${each.key}${local.sfx}"
  friendly_name               = title(each.key)
  description                 = each.value.description
  location                    = var.region
  default_table_expiration_ms = each.value.default_table_expiry

  default_encryption_configuration {
    kms_key_name = var.kms_key_id
  }

  labels = {
    layer   = each.key
    managed = "terraform"
  }
}

# ── Audit table: pipeline job history ────────────────────────────────────────
resource "google_bigquery_table" "pipeline_jobs" {
  dataset_id  = google_bigquery_dataset.pipeline["audit"].dataset_id
  table_id    = "pipeline_jobs"
  description = "One row per ingestion job; updated at each pipeline stage transition"

  deletion_protection = true

  lifecycle {
    ignore_changes = [encryption_configuration]
  }

  time_partitioning {
    type  = "DAY"
    field = "created_at"
  }

  clustering = ["dataset", "status"]

  schema = jsonencode([
    { name = "job_id",           type = "STRING",    mode = "REQUIRED" },
    { name = "dataset",          type = "STRING",    mode = "REQUIRED" },
    { name = "filename",         type = "STRING",    mode = "REQUIRED" },
    { name = "file_size_bytes",  type = "INTEGER",   mode = "NULLABLE" },
    { name = "status",           type = "STRING",    mode = "REQUIRED" },
    { name = "uploaded_by",      type = "STRING",    mode = "NULLABLE" },
    { name = "created_at",       type = "TIMESTAMP", mode = "REQUIRED" },
    { name = "updated_at",       type = "TIMESTAMP", mode = "REQUIRED" },
    { name = "bronze_path",      type = "STRING",    mode = "NULLABLE" },
    { name = "silver_path",      type = "STRING",    mode = "NULLABLE" },
    { name = "bq_table",         type = "STRING",    mode = "NULLABLE" },
    { name = "total_records",    type = "INTEGER",   mode = "NULLABLE" },
    { name = "valid_records",    type = "INTEGER",   mode = "NULLABLE" },
    { name = "rejected_records", type = "INTEGER",   mode = "NULLABLE" },
    { name = "loaded_records",   type = "INTEGER",   mode = "NULLABLE" },
    { name = "error",            type = "STRING",    mode = "NULLABLE" },
  ])
}

# ── Audit table: dataset version snapshots (for ML reproducibility) ───────────
resource "google_bigquery_table" "dataset_versions" {
  dataset_id  = google_bigquery_dataset.pipeline["audit"].dataset_id
  table_id    = "dataset_versions"
  description = "Immutable snapshot metadata per Dataflow run; enables reproducible ML training"

  deletion_protection = true

  lifecycle {
    ignore_changes = [encryption_configuration]
  }

  time_partitioning {
    type  = "DAY"
    field = "snapshot_ts"
  }

  clustering = ["dataset", "job_id"]

  schema = jsonencode([
    { name = "job_id",            type = "STRING",    mode = "REQUIRED" },
    { name = "dataset",           type = "STRING",    mode = "REQUIRED" },
    { name = "schema_version",    type = "STRING",    mode = "NULLABLE" },
    { name = "snapshot_ts",       type = "TIMESTAMP", mode = "REQUIRED" },
    { name = "row_count",         type = "INTEGER",   mode = "NULLABLE" },
    { name = "quality_score",     type = "FLOAT",     mode = "NULLABLE" },
    { name = "gcs_snapshot_path", type = "STRING",    mode = "NULLABLE" },
    { name = "bq_snapshot_table", type = "STRING",    mode = "NULLABLE" },
  ])
}
