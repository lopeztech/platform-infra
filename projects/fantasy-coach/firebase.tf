# ── Firebase Project ─────────────────────────────────────────────────────────
# Initialises Firebase on the GCP project. Required before any Firebase
# resources (Hosting, Auth, Web App) can be created.

resource "google_firebase_project" "default" {
  provider = google-beta
  project  = var.project_id

  depends_on = [google_project_service.apis]
}

# ── Firebase Hosting ─────────────────────────────────────────────────────────
# Serves the Vite + React SPA from lopeztech/fantasy-coach (web/). Custom
# domain points at fantasy.lopezcloud.dev; the default *.web.app URL stays
# available for rollback and smoke-testing.

resource "google_firebase_hosting_site" "app" {
  provider = google-beta
  project  = var.project_id
  site_id  = var.project_id # fantasy-coach-lcd → fantasy-coach-lcd.web.app

  depends_on = [google_firebase_project.default]
}

resource "google_firebase_hosting_custom_domain" "app" {
  provider      = google-beta
  project       = var.project_id
  site_id       = google_firebase_hosting_site.app.site_id
  custom_domain = var.domain # fantasy.lopezcloud.dev

  # We skip Terraform's DNS-verification wait because the Cloudflare CNAME is
  # created in parallel in dns.tf. Firebase will verify the domain as soon as
  # DNS propagates (usually <5 min) and then issue the managed certificate.
  wait_dns_verification = false
}

# ── Firebase Web App ─────────────────────────────────────────────────────────
# Registers a Firebase Web App so the browser SDK can initialise. The config
# (api_key, auth_domain, app_id) is fetched via the data source and published
# to Secret Manager in firebase_secrets.tf so the app-repo deploy workflow
# can build the SPA with live values.

resource "google_firebase_web_app" "app" {
  provider        = google-beta
  project         = var.project_id
  display_name    = "Fantasy Coach"
  deletion_policy = "DELETE"

  depends_on = [google_firebase_project.default]
}

data "google_firebase_web_app_config" "app" {
  provider   = google-beta
  project    = var.project_id
  web_app_id = google_firebase_web_app.app.app_id
}

# ── Firebase Auth / Identity Platform ────────────────────────────────────────
# Custom Hosting domains aren't auto-added to Firebase Auth's authorized-
# domains list — without an entry here, sign-in from fantasy.lopezcloud.dev
# fails with auth/unauthorized-domain. Terraform takes full ownership of the
# list, so every origin that must work for sign-in needs to be listed.
#
# Entries:
#   - localhost: dev server + Vite preview
#   - *.firebaseapp.com / *.web.app: Firebase Hosting defaults (also used by
#     signInWithPopup's redirect flow under the hood)
#   - fantasy.lopezcloud.dev: the production custom domain (this PR)

resource "google_identity_platform_config" "default" {
  project = var.project_id

  authorized_domains = [
    "localhost",
    "${var.project_id}.firebaseapp.com",
    "${var.project_id}.web.app",
    var.domain,
  ]

  depends_on = [google_project_service.apis]
}
