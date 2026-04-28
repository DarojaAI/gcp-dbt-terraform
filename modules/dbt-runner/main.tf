# =============================================================================
# Cloud Run Job for dbt — Executes dbt migrations and tests
# =============================================================================

resource "google_cloud_run_v2_job" "dbt" {
  project  = var.project_id
  name     = "${var.repo_prefix}-${var.environment}-dbt"
  location = var.region
  labels   = var.labels

  template {
    parallelism = 1
    task_count  = var.job_task_count
    
    # VPC configuration at template level (outer) for network egress
    vpc_access {
      network_interfaces {
        network    = var.network_id
        subnetwork = var.subnetwork_id
      }
      egress = "PRIVATE_RANGES_ONLY"
    }

    template {
      timeout = "${var.job_timeout_seconds}s"

      containers {
        image = var.dbt_image_uri

        # Environment variables — database connection
        env {
          name  = "POSTGRES_HOST"
          value = var.postgres_host
        }

        env {
          name  = "POSTGRES_PORT"
          value = tostring(var.postgres_port)
        }

        env {
          name  = "POSTGRES_DB"
          value = var.postgres_db
        }

        env {
          name  = "POSTGRES_USER"
          value = var.postgres_user
        }

        env {
          name  = "DBT_SCHEMA_PREFIX"
          value = var.dbt_schema_prefix
        }

        env {
          name  = "DBT_TARGET"
          value = var.dbt_target
        }

        env {
          name  = "DBT_COMMAND"
          value = var.dbt_command
        }

        # Database password from Secret Manager (never hardcoded)
        env {
          name = "POSTGRES_PASSWORD"
          value_source {
            secret_key_ref {
              secret  = var.postgres_password_secret
              version = "latest"
            }
          }
        }

        # Resource limits
        resources {
          limits = {
            cpu    = var.job_cpu
            memory = var.job_memory
          }
        }
      }

      # Service account for the job
      service_account = google_service_account.dbt_runner.email

      max_retries = 0
    }
  }
}

# =============================================================================
# IAM — Allow GitHub Actions (WIF) to trigger the job
# =============================================================================

resource "google_service_account_iam_member" "gha_wif_service_account" {
  service_account_id = google_service_account.dbt_runner.name
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${var.wif_service_account}"
}

resource "google_cloud_run_v2_job_iam_member" "gha_wif_execute" {
  project  = var.project_id
  location = google_cloud_run_v2_job.dbt.location
  name     = google_cloud_run_v2_job.dbt.name
  role     = "roles/run.invoker"
  member   = "serviceAccount:${var.wif_service_account}"
}

# =============================================================================
# Service Account — for dbt job execution
# =============================================================================

resource "google_service_account" "dbt_runner" {
  project      = var.project_id
  account_id   = "${var.repo_prefix}-${var.environment}-dbt-runner"
  display_name = "Service account for dbt Cloud Run Job (${var.environment})"
}

# =============================================================================
# Security — allow dbt job to read database password from Secret Manager
# =============================================================================

resource "google_secret_manager_secret_iam_member" "dbt_read_db_password" {
  secret_id = var.postgres_password_secret
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.dbt_runner.email}"
}

# =============================================================================
# Security — allow dbt job to access VPC (for PostgreSQL connectivity)
# Note: VPC access is controlled at the subnetwork level, not network level
# The Cloud Run job will use the subnetwork specified in vpc_access config
# =============================================================================

resource "google_compute_subnetwork_iam_member" "dbt_vpc_access" {
  subnetwork = var.subnetwork_id
  role       = "roles/compute.networkUser"
  member     = "serviceAccount:${google_service_account.dbt_runner.email}"
}
