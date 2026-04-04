terraform {
  required_version = ">= 1.6"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 5.0"
    }
  }

  backend "gcs" {
    # Populated at init time:
    #   terraform init \
    #     -backend-config="bucket=platform-infra-lcd-tf-state" \
    #     -backend-config="prefix=terraform/state/finance-doctor/prod"
  }
}
