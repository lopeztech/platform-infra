locals {
  sfx = var.env != "" ? "-${var.env}" : ""
}

# ── Notification Channel ────────────────────────────────────────────────────

resource "google_monitoring_notification_channel" "email" {
  project      = var.project_id
  display_name = "Alert Email${local.sfx}"
  type         = "email"

  labels = {
    email_address = var.notification_email
  }
}

# ── Uptime Checks ──────────────────────────────────────────────────────────

resource "google_monitoring_uptime_check_config" "https" {
  for_each = var.services

  project      = var.project_id
  display_name = "${coalesce(each.value.display_name, each.key)}${local.sfx}"
  timeout      = "10s"
  period       = "300s"

  http_check {
    path         = each.value.path
    port         = 443
    use_ssl      = true
    validate_ssl = true
  }

  monitored_resource {
    type = "uptime_url"
    labels = {
      project_id = var.project_id
      host       = each.value.domain
    }
  }
}

# ── Alert Policy: Uptime failure ────────────────────────────────────────────

resource "google_monitoring_alert_policy" "uptime" {
  for_each = var.services

  project      = var.project_id
  display_name = "${coalesce(each.value.display_name, each.key)}${local.sfx} Uptime Failure"
  combiner     = "OR"

  conditions {
    display_name = "Uptime check failing"
    condition_threshold {
      filter          = "resource.type = \"uptime_url\" AND metric.type = \"monitoring.googleapis.com/uptime_check/check_passed\" AND metric.labels.check_id = \"${google_monitoring_uptime_check_config.https[each.key].uptime_check_id}\""
      comparison      = "COMPARISON_GT"
      threshold_value = 1
      duration        = "300s"

      aggregations {
        alignment_period     = "1200s"
        cross_series_reducer = "REDUCE_COUNT_FALSE"
        per_series_aligner   = "ALIGN_NEXT_OLDER"
        group_by_fields      = ["resource.label.project_id", "resource.label.host"]
      }

      trigger {
        count = 1
      }
    }
  }

  notification_channels = [google_monitoring_notification_channel.email.name]

  alert_strategy {
    auto_close = "1800s"
  }

  user_labels = {
    managed = "terraform"
  }
}
