# =============================================================================
# Cloud Run Job for dbt migrations and tests
# Executes dbt with direct VPC access to PostgreSQL database
# =============================================================================

terraform {
  required_version = ">= 1.6"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

# Enable Cloud Run API
resource "google_project_service" "cloudrun" {
  project = var.project_id
  service = "cloudrun.googleapis.com"

  disable_on_destroy = false
}

# =============================================================================
# Service Account for dbt Cloud Run Job
# =============================================================================

resource "google_service_account" "dbt_runner" {
  project      = var.project_id
  account_id   = "${var.repo_prefix}-${var.environment}-dbt-runner"
  display_name = "Service account for dbt Cloud Run Job (${var.environment})"
  description  = "Executes dbt migrations on Cloud Run, accesses database secrets"
}

# Grant Secret Manager access (for database password, API keys, etc.)
resource "google_project_iam_member" "dbt_runner_secrets" {
  project = var.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${google_service_account.dbt_runner.email}"
}

# =============================================================================
# Cloud Run Job Definition
# =============================================================================

resource "google_cloud_run_v2_job" "dbt" {
  project  = var.project_id
  name     = "${var.repo_prefix}-${var.environment}-dbt"
  location = var.region
  labels   = var.labels

  template {
    # Job timeout
    timeout = "${var.job_timeout_seconds}s"

    # Task configuration
    task_count  = var.job_task_count
    parallelism = 1

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

    # VPC egress — direct access to PostgreSQL VM on private VPC
    vpc_access {
      # Use direct VPC egress (no VPC Connector needed)
      egress = "ALL_TRAFFIC"

      network_interfaces {
        network    = var.network_id
        subnetwork = var.subnetwork_id
      }
    }

    # Service account for the job
    service_account = google_service_account.dbt_runner.email
  }

  depends_on = [google_project_service.cloudrun]
}

# =============================================================================
# IAM — Allow GitHub Actions (WIF) to trigger the job
# =============================================================================

resource "google_cloud_run_v2_job_iam_member" "github_actions_developer" {
  project  = var.project_id
  name     = google_cloud_run_v2_job.dbt.name
  location = google_cloud_run_v2_job.dbt.location
  role     = "roles/run.developer"
  member   = "serviceAccount:${var.wif_service_account}"
}

# Allow GitHub Actions service account to view logs
resource "google_project_iam_member" "github_actions_logs" {
  project = var.project_id
  role    = "roles/logging.viewer"
  member  = "serviceAccount:${var.wif_service_account}"
}
