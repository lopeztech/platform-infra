locals {
  sfx = var.env != "" ? "-${var.env}" : ""
}

# ── Data ───────────────────────────────────────────────────────────────────────

data "google_project" "project" {
  project_id = var.project_id
}

# ── Notification Channel ──────────────────────────────────────────────────────

resource "google_monitoring_notification_channel" "budget_email" {
  project      = var.project_id
  display_name = "Budget Alert Email${local.sfx}"
  type         = "email"

  labels = {
    email_address = var.notification_email
  }
}

# ── Budget ────────────────────────────────────────────────────────────────────

resource "google_billing_budget" "project" {
  billing_account = var.billing_account
  display_name    = "${var.project_id}${local.sfx} Monthly Budget"

  budget_filter {
    projects = ["projects/${data.google_project.project.number}"]
  }

  amount {
    specified_amount {
      currency_code = "USD"
      units         = tostring(var.monthly_budget_usd)
    }
  }

  dynamic "threshold_rules" {
    for_each = var.threshold_percentages
    content {
      threshold_percent = threshold_rules.value
      spend_basis       = "CURRENT_SPEND"
    }
  }

  # Also alert on forecasted spend exceeding 100%
  threshold_rules {
    threshold_percent = 1.0
    spend_basis       = "FORECASTED_SPEND"
  }

  all_updates_rule {
    monitoring_notification_channels = [
      google_monitoring_notification_channel.budget_email.id,
    ]
    pubsub_topic                   = var.pubsub_topic_id
    disable_default_iam_recipients = false
  }
}
