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
# Minimum set for #14 (Cloud Run + Artifact Registry + IAM/WIF). Firestore,
# Secret Manager, Firebase, and Vertex APIs are added in their own issues
# (#15, #16, #17, #19, #22) so each gets reviewed independently.

resource "google_project_service" "apis" {
  for_each = toset([
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
  ])

  project            = var.project_id
  service            = each.value
  disable_on_destroy = false
}

data "google_project" "project" {
  project_id = var.project_id
}
