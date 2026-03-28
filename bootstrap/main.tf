# bootstrap/main.tf
# Run this manually ONCE per environment before any project's terraform init.
# It creates the GCS state bucket and enables all required GCP APIs.
# Nothing here should ever be managed by CI/CD automation.

terraform {
  required_version = ">= 1.6"
  # Intentionally local state — this is the chicken-and-egg root
  # (the state bucket doesn't exist yet when this runs)
}

variable "project_id" { type = string }
variable "region"     { type = string }
variable "env"        { type = string }

locals {
  state_bucket = "${var.project_id}-tf-state"
}

provider "google" {
  project = var.project_id
  region  = var.region
}

resource "google_storage_bucket" "tf_state" {
  name                        = local.state_bucket
  location                    = var.region
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  force_destroy               = false

  versioning {
    enabled = true
  }

  lifecycle_rule {
    action { type = "Delete" }
    condition {
      num_newer_versions = 10  # keep last 10 state versions
      with_state         = "ARCHIVED"
    }
  }

  labels = {
    env     = var.env
    purpose = "terraform-state"
    managed = "terraform-bootstrap"
  }
}

locals {
  required_apis = [
    "cloudresourcemanager.googleapis.com",
    "iam.googleapis.com",
    "iamcredentials.googleapis.com",
    "storage.googleapis.com",
    "pubsub.googleapis.com",
    "bigquery.googleapis.com",
    "firestore.googleapis.com",
    "run.googleapis.com",
    "cloudfunctions.googleapis.com",
    "cloudbuild.googleapis.com",
    "secretmanager.googleapis.com",
    "cloudkms.googleapis.com",
    "artifactregistry.googleapis.com",
    "dataflow.googleapis.com",
    "monitoring.googleapis.com",
    "logging.googleapis.com",
  ]
}

resource "google_project_service" "apis" {
  for_each = toset(local.required_apis)

  service            = each.value
  disable_on_destroy = false
}

output "state_bucket" {
  value = google_storage_bucket.tf_state.name
}

output "next_steps" {
  value = <<-EOT
    Bootstrap complete. Now initialise a project:

      cd projects/<your-project>
      terraform init \\
        -backend-config="bucket=${local.state_bucket}" \\
        -backend-config="prefix=terraform/state/<your-project>"
      terraform apply
  EOT
}
