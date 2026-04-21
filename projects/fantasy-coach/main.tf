provider "google" {
  project = var.project_id
  region  = var.region
}

locals {
  app_name = "fantasy-coach"
  labels = {
    app         = local.app_name
    environment = var.environment
    managed_by  = "terraform"
  }
}

# ── APIs ─────────────────────────────────────────────────────────────────────
# Incrementally extended per issue so each scope lands in its own review:
#   #14 (Cloud Run + Artifact Registry + IAM/WIF) — originally added here.
#   #19 (SPA + Firebase Hosting + custom domain) — adds firebase/hosting/
#       identitytoolkit/secretmanager. Covers Firebase Auth Google sign-in
#       from fantasy.lopezcloud.dev and publishing the Web App config.
# Firestore (#15) and Vertex AI (#22) are still pending their own PRs.

resource "google_project_service" "apis" {
  for_each = toset([
    # Needed by the google provider itself for project IAM reads. Without
    # this, every terraform plan in CI fails with "Cloud Resource Manager
    # API has not been used in project N" — the deployer SA's quota project
    # is fantasy-coach-lcd, and the API has to be enabled there.
    "cloudresourcemanager.googleapis.com",
    "iam.googleapis.com",
    "iamcredentials.googleapis.com",
    "sts.googleapis.com",
    "run.googleapis.com",
    "artifactregistry.googleapis.com",
    "cloudbuild.googleapis.com",
    "cloudbilling.googleapis.com",
    "billingbudgets.googleapis.com",
    "serviceusage.googleapis.com",
    "logging.googleapis.com",
    "monitoring.googleapis.com",
    # Added in #19 (SPA hosting + auth).
    "firebase.googleapis.com",
    "firebasehosting.googleapis.com",
    "identitytoolkit.googleapis.com",
    "secretmanager.googleapis.com",
  ])

  project            = var.project_id
  service            = each.value
  disable_on_destroy = false
}

data "google_project" "project" {
  project_id = var.project_id
}
