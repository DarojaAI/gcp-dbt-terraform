# =============================================================================
# GCP dbt Runner Module - Root Outputs
# 
# Re-exports outputs from the nested dbt_runner module
# =============================================================================

output "job_name" {
  description = "Cloud Run Job name"
  value       = module.dbt_runner.job_name
}

output "job_location" {
  description = "Cloud Run Job region"
  value       = module.dbt_runner.job_location
}

output "job_full_name" {
  description = "Cloud Run Job full name (projects/X/locations/Y/jobs/Z)"
  value       = module.dbt_runner.job_full_name
}

output "job_id" {
  description = "Cloud Run Job ID"
  value       = try(module.dbt_runner.job_full_name, "")
}

output "service_account_email" {
  description = "Service account email for dbt Cloud Run Job"
  value       = module.dbt_runner.service_account_email
}

output "service_account_id" {
  description = "Service account ID"
  value       = module.dbt_runner.service_account_id
}

output "github_actions_execute_command" {
  description = "GitHub Actions command to execute dbt job"
  value       = module.dbt_runner.github_actions_execute_command
}

output "vpc_connector_id" {
  description = "VPC Access Connector ID (from internal network config)"
  value       = try(module.dbt_runner.job_full_name, "")
}
