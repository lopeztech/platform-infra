# ── Firebase Project ──────────────────────────────────────────────────────────
# Initialises Firebase on the GCP project. Required before any Firebase
# resources (Hosting, etc.) can be created.
# Created via gcloud in CI — import into state on first run.

import {
  id = "projects/data-feeder-lcd"
  to = google_firebase_project.default
}

resource "google_firebase_project" "default" {
  provider = google-beta
  project  = var.project_id

  depends_on = [google_project_service.apis]
}

# ── Firebase Hosting ──────────────────────────────────────────────────────────
# Serves the Vite React SPA as static files. Replaces the previous Cloud Run +
# HTTPS load balancer frontend.

resource "google_firebase_hosting_site" "data_feeder" {
  provider = google-beta
  project  = var.project_id
  site_id  = var.project_id # data-feeder-lcd → data-feeder-lcd.web.app

  depends_on = [google_firebase_project.default]
}

resource "google_firebase_hosting_custom_domain" "data_feeder" {
  provider      = google-beta
  project       = var.project_id
  site_id       = google_firebase_hosting_site.data_feeder.site_id
  custom_domain = var.domain # datafeeder.lopezcloud.dev

  wait_dns_verification = false
}
