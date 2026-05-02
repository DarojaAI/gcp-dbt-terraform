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

  # Cloud Run Job Configuration
  job_timeout_seconds = var.job_timeout_seconds
  job_cpu             = var.job_cpu
  job_memory          = var.job_memory
  job_task_count      = var.job_task_count
  job_max_retries     = var.job_max_retries
  job_parallelism     = var.job_parallelism

  # Labels
  labels = var.labels

  # Smoke Test
  run_smoke_test = var.run_smoke_test

  # Custom env vars
  dbt_env_vars = var.dbt_env_vars

  # Artifacts bucket
  artifacts_bucket_name     = var.artifacts_bucket_name
  artifacts_bucket_location = var.artifacts_bucket_location
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
  description = "Cloud Run Job ID (derived from full name)"
  value       = try(split("/", module.dbt_runner.job_full_name)[5], "")
}

output "service_account_email" {
  description = "Service account email for dbt Cloud Run Job"
  value       = module.dbt_runner.service_account_email
}

output "container_env_names" {
  description = "Names of all env vars set on the dbt container."
  value       = module.dbt_runner.container_env_names
}

output "max_retries" {
  description = "Resolved max_retries on the Cloud Run Job."
  value       = module.dbt_runner.max_retries
}

output "parallelism" {
  description = "Resolved parallelism on the Cloud Run Job."
  value       = module.dbt_runner.parallelism
}

output "artifacts_bucket_name" {
  description = "GCS bucket name for dbt artifacts (null if disabled)."
  value       = module.dbt_runner.artifacts_bucket_name
}

output "artifacts_bucket_url" {
  description = "gs:// URL of the dbt artifacts bucket (null if disabled)."
  value       = module.dbt_runner.artifacts_bucket_url
}
