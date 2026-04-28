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
