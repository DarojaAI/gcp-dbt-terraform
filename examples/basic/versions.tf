# Pinned to match repo root. The fake provider config lets `terraform plan`
# run without GCP credentials — no API calls are made during plan.
terraform {
  required_version = ">= 1.6"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 7.0"
    }
  }
}

provider "google" {
  project = "fake-project-for-plan-only"
  region  = "us-central1"
}
