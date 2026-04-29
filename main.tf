# =============================================================================
# GCP dbt Runner Terraform Module - Root Wrapper
#
# This module follows Terraform standard structure by providing the primary
# entrypoint at the repository root. It wraps and re-exports the dbt-runner
# nested module.
#
# For advanced users who need multiple dbt configurations, the modules/
# subdirectory provides additional nested modules.
#
# See: https://developer.hashicorp.com/terraform/language/modules/develop/structure
# =============================================================================

module "dbt_runner" {
  source = "./modules/dbt-runner"

  project_id  = var.project_id
  region      = var.region
  environment = var.environment
  repo_prefix = var.repo_prefix

  # VPC Configuration
  network_id    = var.network_id
  subnetwork_id = var.subnetwork_id

  # Database Connection
  postgres_host            = var.postgres_host
  postgres_port            = var.postgres_port
  postgres_user            = var.postgres_user
  postgres_db              = var.postgres_db
  postgres_password_secret = var.postgres_password_secret

  # Docker Image
  dbt_image_uri = var.dbt_image_uri

  # dbt Configuration
  dbt_schema_prefix = var.dbt_schema_prefix
  dbt_target        = var.dbt_target
  dbt_command       = var.dbt_command

  # GitHub Actions WIF
  wif_service_account = var.wif_service_account

  # Labels
  labels = var.labels
}

# =============================================================================
# Re-export all outputs from nested module
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
  description = "Service account email for dbt Cloud Run Job"
  value       = module.dbt_runner.service_account_email
}

output "vpc_connector_id" {
  description = "VPC Access Connector ID"
  value       = module.dbt_runner.vpc_connector_id
}
