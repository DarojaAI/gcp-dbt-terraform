# =============================================================================
# Basic Example - Terraform Test Harness
#
# This example provides a minimal configuration for terraform test.
# It instantiates the root module and re-exports outputs for assertions.
# =============================================================================

module "dbt_runner" {
  source = "../.."

  project_id  = "test-project"
  region      = "us-central1"
  environment = "ci"
  repo_prefix = "rag-research"

  # VPC Configuration (required, but values don't matter for plan-only tests)
  network_id    = "projects/test-project/global/networks/default"
  subnetwork_id = "projects/test-project/regions/us-central1/subnetworks/default"

  # Database Connection (required, but values don't matter for plan-only tests)
  postgres_host            = "10.0.0.5"
  postgres_password_secret = "projects/test-project/secrets/db-password/versions/latest"

  # Docker Image (placeholder for plan)
  dbt_image_uri = "gcr.io/test-project/dbt:latest"

  # GitHub Actions WIF (required)
  wif_service_account = "test-project.svc.id.goog:[...]"
}

# =============================================================================
# Re-export outputs for terraform test assertions
# =============================================================================

output "job_name" {
  description = "Cloud Run Job name"
  value       = module.dbt_runner.job_name
}

output "job_location" {
  description = "Cloud Run Job region"
  value       = module.dbt_runner.job_location
}

output "job_id" {
  description = "Cloud Run Job ID"
  value       = module.dbt_runner.job_id
}

output "service_account_email" {
  description = "Service account email"
  value       = module.dbt_runner.service_account_email
}