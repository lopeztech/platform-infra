module "monitoring" {
  source = "../../modules/monitoring"

  project_id         = var.project_id
  env                = var.environment
  notification_email = var.notification_email

  services = {
    "plant-tracker" = {
      domain       = var.domain
      path         = "/"
      display_name = "Plant Tracker"
    }
  }

  depends_on = [google_project_service.apis]
}

# ── Budget Alerts ──────────────────────────────────────────────────────────────

module "budget" {
  source = "../../modules/budget"

  project_id          = var.project_id
  env                 = var.environment
  billing_account     = var.billing_account
  monthly_budget_usd  = var.monthly_budget_usd
  notification_email  = var.notification_email

  depends_on = [google_project_service.apis]
}
