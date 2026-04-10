# ── Firebase Project ──────────────────────────────────────────────────────────

resource "google_firebase_project" "default" {
  provider = google-beta
  project  = var.project_id

  depends_on = [google_project_service.apis]
}

# ── Firebase Hosting ──────────────────────────────────────────────────────────
# Serves the React SPA as static files. Replaces the previous GCS bucket +
# Cloud CDN + HTTPS load balancer frontend.

resource "google_firebase_hosting_site" "app" {
  provider = google-beta
  project  = var.project_id
  site_id  = "${var.project_id}-sre-monitor"

  depends_on = [google_firebase_project.default]
}

resource "google_firebase_hosting_custom_domain" "app" {
  provider      = google-beta
  project       = var.project_id
  site_id       = google_firebase_hosting_site.app.site_id
  custom_domain = var.domain

  wait_dns_verification = false
}
