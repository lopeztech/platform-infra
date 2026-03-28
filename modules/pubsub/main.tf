locals {
  sfx = var.env != "" ? "-${var.env}" : ""

  topics = {
    "file-uploaded"       = "Triggered by GCS Bronze finalize; consumed by validator Cloud Function"
    "validation-complete" = "Published by validator; consumed by Dataflow Silver→Gold pipeline"
    "pipeline-failed"     = "Published on any pipeline stage failure; consumed by alerting"
  }
}

resource "google_pubsub_topic" "pipeline" {
  for_each = local.topics

  name = "${each.key}${local.sfx}"

  message_retention_duration = "604800s" # 7 days

  labels = {
    managed = "terraform"
  }
}

# Dead-letter topic — receives messages that exceed max_delivery_attempts
resource "google_pubsub_topic" "dead_letter" {
  name = "pipeline-dlq${local.sfx}"

  message_retention_duration = "604800s"

  labels = {
    managed = "terraform"
  }
}

# ── Subscriptions ─────────────────────────────────────────────────────────────

# Validator Cloud Function pulls from file-uploaded
resource "google_pubsub_subscription" "validator" {
  name  = "validator-sub${local.sfx}"
  topic = google_pubsub_topic.pipeline["file-uploaded"].id

  ack_deadline_seconds = 300 # Cloud Functions max timeout

  dead_letter_policy {
    dead_letter_topic     = google_pubsub_topic.dead_letter.id
    max_delivery_attempts = 5
  }

  retry_policy {
    minimum_backoff = "10s"
    maximum_backoff = "600s"
  }

  labels = {
    managed = "terraform"
  }
}

# Dataflow job pulls from validation-complete (long ack deadline for large jobs)
resource "google_pubsub_subscription" "dataflow" {
  name  = "dataflow-sub${local.sfx}"
  topic = google_pubsub_topic.pipeline["validation-complete"].id

  ack_deadline_seconds         = 600  # Dataflow jobs can run for 10+ minutes
  enable_exactly_once_delivery = true

  dead_letter_policy {
    dead_letter_topic     = google_pubsub_topic.dead_letter.id
    max_delivery_attempts = 5
  }

  retry_policy {
    minimum_backoff = "30s"
    maximum_backoff = "600s"
  }

  labels = {
    managed = "terraform"
  }
}

# Alerting subscription on pipeline-failed
resource "google_pubsub_subscription" "alerting" {
  name  = "alerting-sub${local.sfx}"
  topic = google_pubsub_topic.pipeline["pipeline-failed"].id

  ack_deadline_seconds = 60

  dead_letter_policy {
    dead_letter_topic     = google_pubsub_topic.dead_letter.id
    max_delivery_attempts = 5
  }

  labels = {
    managed = "terraform"
  }
}

# DLQ monitoring subscription — lets ops team inspect failed messages
resource "google_pubsub_subscription" "dlq_monitor" {
  name  = "dlq-monitor-sub${local.sfx}"
  topic = google_pubsub_topic.dead_letter.id

  ack_deadline_seconds       = 60
  message_retention_duration = "604800s"

  labels = {
    managed = "terraform"
  }
}
