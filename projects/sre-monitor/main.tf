provider "google" {
  project               = var.project_id
  region                = var.region
  user_project_override = true
  billing_project       = var.project_id
}

provider "google-beta" {
  project               = var.project_id
  region                = var.region
  user_project_override = true
  billing_project       = var.project_id
}

locals {
  app_name = "sre-monitor"
  labels = {
    app         = local.app_name
    environment = var.environment
    managed_by  = "terraform"
  }
}

resource "google_project_service" "apis" {
  for_each = toset([
    "compute.googleapis.com",
    "storage.googleapis.com",
    "iam.googleapis.com",
    "iamcredentials.googleapis.com",
    "sts.googleapis.com",
    "run.googleapis.com",
    "cloudfunctions.googleapis.com",
    "cloudbuild.googleapis.com",
    "artifactregistry.googleapis.com",
    "monitoring.googleapis.com",
    "secretmanager.googleapis.com",
    "billingbudgets.googleapis.com",
    "bigquery.googleapis.com",
    "firebase.googleapis.com",
    "firebasehosting.googleapis.com",
  ])

  project            = var.project_id
  service            = each.value
  disable_on_destroy = false
}

data "google_project" "project" {
  project_id = var.project_id
}
