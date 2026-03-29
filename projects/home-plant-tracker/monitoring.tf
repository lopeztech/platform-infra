module "monitoring" {
  source = "../../modules/monitoring"

  project_id         = var.project_id
  env                = var.environment
  notification_email = var.notification_email

  services = {
    "plant-tracker" = {
      domain       = var.domain
      path         = "/health"
      display_name = "Plant Tracker"
    }
  }

  depends_on = [google_project_service.apis]
}
