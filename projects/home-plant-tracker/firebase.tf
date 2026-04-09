# ── Firebase Project ──────────────────────────────────────────────────────────
# Initialises Firebase on the GCP project. Required before any Firebase
# resources (Hosting, etc.) can be created.

resource "google_firebase_project" "default" {
  provider = google-beta
  project  = var.project_id

  depends_on = [google_project_service.apis]
}

# ── Firebase Hosting ──────────────────────────────────────────────────────────
# Serves the Vite React SPA as static files. Replaces the previous Cloud Run +
# Cloud CDN frontend — Firebase Hosting is free-tier eligible and purpose-built
# for SPAs.

resource "google_firebase_hosting_site" "plant_tracker" {
  provider = google-beta
  project  = var.project_id
  site_id  = "${local.app_name}-${var.environment}"

  depends_on = [google_firebase_project.default]
}

resource "google_firebase_hosting_custom_domain" "plant_tracker" {
  provider      = google-beta
  project       = var.project_id
  site_id       = google_firebase_hosting_site.plant_tracker.site_id
  custom_domain = var.domain

  wait_dns_verification = false
}
