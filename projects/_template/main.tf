# Template for a new project. Copy this directory to projects/<your-project>/
# and replace all occurrences of "your-project" with your project name.

terraform {
  required_version = ">= 1.6"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }

  backend "gcs" {}
}

provider "google" {
  project = var.project_id
  region  = var.region
}

locals {
  module_source = "git::https://github.com/lopeztech/platform-infra//modules"
  module_ref    = var.platform_infra_ref
}

# Add only the modules your project needs.
# Available: gcs, iam, bigquery, pubsub, firestore, cloudrun, secretmanager
