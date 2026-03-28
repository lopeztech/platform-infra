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
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
  }

  backend "gcs" {
    # Populated at init time:
    #   terraform init \
    #     -backend-config="bucket=platform-infra-tf-state" \
    #     -backend-config="prefix=terraform/state/home-plant-tracker/prod"
  }
}
