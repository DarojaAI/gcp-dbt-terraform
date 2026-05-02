# =============================================================================
# Outputs — dbt Runner Module
# =============================================================================

output "job_name" {
  description = "Cloud Run Job name (use in GitHub Actions: gcloud run jobs execute <name>)"
  value       = google_cloud_run_v2_job.dbt.name
}

output "job_location" {
  description = "Cloud Run Job location"
  value       = google_cloud_run_v2_job.dbt.location
}

output "job_full_name" {
  description = "Full resource name for the Cloud Run Job"
  value       = google_cloud_run_v2_job.dbt.id
}

output "service_account_email" {
  description = "Service account email used by the dbt Cloud Run Job"
  value       = google_service_account.dbt_runner.email
}

output "service_account_id" {
  description = "Service account ID"
  value       = google_service_account.dbt_runner.unique_id
}

output "container_env_names" {
  description = "Names of all env vars set on the dbt container — used by terraform test to verify pass-through."
  value       = [for e in google_cloud_run_v2_job.dbt.template[0].template[0].containers[0].env : e.name]
}

output "max_retries" {
  description = "Resolved max_retries on the Cloud Run Job — used by terraform test."
  value       = google_cloud_run_v2_job.dbt.template[0].template[0].max_retries
}

output "parallelism" {
  description = "Resolved parallelism on the Cloud Run Job — used by terraform test."
  value       = google_cloud_run_v2_job.dbt.template[0].parallelism
}

output "artifacts_bucket_name" {
  description = "GCS bucket name for dbt artifacts (null if disabled)."
  value       = local.artifacts_enabled ? google_storage_bucket.artifacts[0].name : null
}

output "artifacts_bucket_url" {
  description = "gs:// URL of the dbt artifacts bucket (null if disabled)."
  value       = local.artifacts_enabled ? google_storage_bucket.artifacts[0].url : null
}

# GitHub Actions command to execute the job
output "github_actions_execute_command" {
  description = "GitHub Actions command to execute the dbt job"
  value = join(" ", [
    "gcloud run jobs execute",
    google_cloud_run_v2_job.dbt.name,
    "--region ${google_cloud_run_v2_job.dbt.location}",
    "--project ${var.project_id}",
    "--wait"
  ])
}
