# ── Firebase Project ──────────────────────────────────────────────────────────
# Initialises Firebase on the GCP project. Required before any Firebase
# resources (Hosting, Functions, Auth) can be created.

resource "google_firebase_project" "default" {
  provider = google-beta
  project  = var.project_id

  depends_on = [google_project_service.apis]
}

# ── Firebase Hosting ──────────────────────────────────────────────────────────
# Will serve the static-exported Next.js app once the app-side migration lands.
# Until then, Cloud Run remains the production frontend.

resource "google_firebase_hosting_site" "app" {
  provider = google-beta
  project  = var.project_id
  site_id  = var.project_id # finance-doctor-lcd → finance-doctor-lcd.web.app

  depends_on = [google_firebase_project.default]
}

resource "google_firebase_hosting_custom_domain" "app" {
  provider      = google-beta
  project       = var.project_id
  site_id       = google_firebase_hosting_site.app.site_id
  custom_domain = var.domain # finance.lopezcloud.dev

  wait_dns_verification = false
}

# ── Firestore Security Rules ──────────────────────────────────────────────────
# Establishes default-deny with per-user access scoped by request.auth.uid.
# App-side migrations (#49–#51) will refine these rules as each collection
# moves to the client SDK.

resource "google_firebaserules_ruleset" "firestore" {
  project = var.project_id

  source {
    files {
      name    = "firestore.rules"
      content = file("${path.module}/firestore.rules")
    }
  }

  depends_on = [
    google_firestore_database.default,
    google_project_service.apis,
  ]
}

resource "google_firebaserules_release" "firestore" {
  project      = var.project_id
  name         = "cloud.firestore"
  ruleset_name = google_firebaserules_ruleset.firestore.name

  lifecycle {
    replace_triggered_by = [google_firebaserules_ruleset.firestore]
  }
}

# ── Functions Runtime Service Account ─────────────────────────────────────────
# Used by Callable Cloud Functions (Gemini proxies, etc.) once #52 lands.
# Created up-front so app-side work in later issues has an identity to target.

resource "google_service_account" "functions_runtime" {
  account_id   = "${local.app_name}-functions"
  display_name = "Finance Doctor Cloud Functions Runtime"
  description  = "Service account for Finance Doctor Callable Cloud Functions"
  project      = var.project_id

  depends_on = [google_project_service.apis]
}

resource "google_project_iam_member" "functions_runtime_firestore" {
  project = var.project_id
  role    = "roles/datastore.user"
  member  = "serviceAccount:${google_service_account.functions_runtime.email}"
}

resource "google_project_iam_member" "functions_runtime_vertex_ai" {
  project = var.project_id
  role    = "roles/aiplatform.user"
  member  = "serviceAccount:${google_service_account.functions_runtime.email}"
}

resource "google_project_iam_member" "functions_runtime_secret_accessor" {
  project = var.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${google_service_account.functions_runtime.email}"
}
