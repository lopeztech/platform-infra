# ── Budget Alerts ─────────────────────────────────────────────────────────────
# Two budgets, one notification channel:
#
#   - Project-wide cap (var.monthly_budget_usd, via the shared budget module)
#     — catches runaway spend on any service. Thresholds 50/80/100% current +
#     100% forecasted.
#
#   - Vertex AI specific (var.vertex_ai_monthly_budget_aud, filtered on service
#     ID C7E2-9256-1C43) — early warning for Gemini call volume blowing out.
#     Gemini dominates the project's cost profile, so we want visibility
#     well before the project-wide cap trips.
#
# Both alerts fire into the email channel provisioned inside the budget
# module; the Vertex AI budget reuses that channel via module output so we
# don't maintain two identical channels.

module "budget" {
  source = "../../modules/budget"

  project_id         = var.project_id
  env                = var.environment
  billing_account    = var.billing_account
  monthly_budget_usd = var.monthly_budget_usd
  notification_email = var.notification_email

  depends_on = [google_project_service.apis]
}

# Vertex AI service ID in the Cloud Billing catalog. Verified 2026-04-18 via
# cloudbilling.googleapis.com/v1/services. If Google changes it, the budget
# will silently stop filtering — revalidate periodically.
locals {
  vertex_ai_service_id = "services/C7E2-9256-1C43"
}

resource "google_billing_budget" "vertex_ai" {
  billing_account = var.billing_account
  display_name    = "${var.project_id}-${var.environment} Vertex AI Budget"

  budget_filter {
    projects = ["projects/${data.google_project.project.number}"]
    services = [local.vertex_ai_service_id]
  }

  amount {
    specified_amount {
      currency_code = "AUD"
      units         = tostring(var.vertex_ai_monthly_budget_aud)
    }
  }

  threshold_rules {
    threshold_percent = 0.5
    spend_basis       = "CURRENT_SPEND"
  }

  threshold_rules {
    threshold_percent = 0.8
    spend_basis       = "CURRENT_SPEND"
  }

  threshold_rules {
    threshold_percent = 1.0
    spend_basis       = "CURRENT_SPEND"
  }

  threshold_rules {
    threshold_percent = 1.0
    spend_basis       = "FORECASTED_SPEND"
  }

  all_updates_rule {
    monitoring_notification_channels = [module.budget.notification_channel_id]
    disable_default_iam_recipients   = false
  }

  depends_on = [google_project_service.apis]
}
