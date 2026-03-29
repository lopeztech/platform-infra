module "monitoring" {
  source = "../../modules/monitoring"

  project_id         = var.project_id
  env                = var.environment
  notification_email = var.notification_email

  services = {
    "sre-monitor" = {
      domain       = var.domain
      path         = "/health"
      display_name = "SRE Monitor"
    }
  }

  depends_on = [google_project_service.apis]
}
