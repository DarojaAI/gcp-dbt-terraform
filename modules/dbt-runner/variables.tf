# =============================================================================
# Input Variables — dbt Runner Module
# =============================================================================
# Reusable Terraform module for Cloud Run Job-based dbt execution
# Uses Hashicorp module structure: https://developer.hashicorp.com/terraform/language/modules/develop/structure

variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod, eai, etc.)"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.environment))
    error_message = "Environment must contain only lowercase letters, numbers, and hyphens"
  }
}

variable "region" {
  description = "GCP region for Cloud Run Job"
  type        = string
  default     = "us-central1"
}

variable "repo_prefix" {
  description = "Repository prefix for resource naming (e.g., rag-research)"
  type        = string
  default     = "rag-research"
}

# =============================================================================
# Database Configuration
# =============================================================================

variable "postgres_host" {
  description = "PostgreSQL database hostname or IP (internal VPC IP for Compute Engine)"
  type        = string
}

variable "postgres_port" {
  description = "PostgreSQL port"
  type        = number
  default     = 5432
}

variable "postgres_db" {
  description = "PostgreSQL database name"
  type        = string
  default     = "rag_taxonomy"
}

variable "postgres_user" {
  description = "PostgreSQL database user"
  type        = string
  default     = "rag_admin"
}

variable "postgres_password_secret" {
  description = "Fully qualified Secret Manager secret reference (projects/X/secrets/Y/versions/Z or projects/X/secrets/Y)"
  type        = string
  # Example: "projects/123456/secrets/postgres-password/versions/latest"
  # Or: "projects/123456/secrets/postgres-password" (auto uses latest)
}

# =============================================================================
# VPC Configuration
# =============================================================================

variable "network_id" {
  description = "VPC network resource ID (for VPC egress to reach PostgreSQL)"
  type        = string
}

variable "subnetwork_id" {
  description = "VPC subnetwork resource ID"
  type        = string
}

# =============================================================================
# Docker Image
# =============================================================================

variable "dbt_image_uri" {
  description = "Full Docker image URI (e.g., gcr.io/project/dbt:latest)"
  type        = string
  # Example: "gcr.io/globalbiting-dev/rag-research-eai-dbt:latest"
}

# =============================================================================
# dbt Configuration
# =============================================================================

variable "dbt_schema_prefix" {
  description = "dbt schema prefix variable"
  type        = string
  default     = "rag"
}

variable "dbt_target" {
  description = "dbt target profile to use"
  type        = string
  default     = "prod"
}

variable "dbt_command" {
  description = "dbt command to run (e.g., 'run', 'test', 'run && test'). Note: shell operators like '&&' are NOT supported in Cloud Run env vars - the command must be a single dbt subcommand without chaining."
  type        = string
  default     = "run --target prod"
  validation {
    condition     = !can(regex("(&&|;|\\|)", var.dbt_command))
    error_message = "Shell operators (&&, ;, |) are not supported in dbt_command. Cloud Run passes env vars as single arguments, not through a shell. Use a single dbt subcommand (e.g., 'run --target prod') or set DBT_COMMAND via a shell wrapper script in the container."
  }
  validation {
    condition     = !can(regex("--vars.*'.*'.*'", var.dbt_command))
    error_message = "JSON in --vars (e.g., --vars '{\"key\": \"value\"}') is not supported in dbt_command env var. JSON gets corrupted by shell escaping. Pass vars via separate environment variables (DBT_VARS) or hardcode them in dbt_project.yml."
  }
}

# =============================================================================
# Cloud Run Job Configuration
# =============================================================================

variable "job_timeout_seconds" {
  description = "Cloud Run Job timeout in seconds"
  type        = number
  default     = 1800 # 30 minutes
}

variable "job_cpu" {
  description = "Cloud Run Job CPU allocation"
  type        = string
  default     = "2"
}

variable "job_memory" {
  description = "Cloud Run Job memory allocation"
  type        = string
  default     = "2Gi"
}

variable "job_task_count" {
  description = "Number of parallel tasks"
  type        = number
  default     = 1
}

variable "job_max_retries" {
  description = "Number of retries for a failed Cloud Run Job task. Default 0 (no retries) preserves current behavior; raise to 1–3 only if the dbt job is idempotent on partial failure."
  type        = number
  default     = 0

  validation {
    condition     = var.job_max_retries >= 0 && var.job_max_retries <= 10
    error_message = "job_max_retries must be between 0 and 10 (Cloud Run hard limit)."
  }
}

variable "job_parallelism" {
  description = "Number of tasks that may run in parallel. Must be <= job_task_count. dbt is generally not safe to run in parallel against the same warehouse — leave at 1 unless you know what you're doing."
  type        = number
  default     = 1
}

# =============================================================================
# Authentication & IAM
# =============================================================================

variable "wif_service_account" {
  description = "Workload Identity Federation service account email (typically GitHub Actions SA)"
  type        = string
  # Example: "github-actions@your-project.iam.gserviceaccount.com"
}

# =============================================================================
# Labeling
# =============================================================================

variable "labels" {
  description = "Labels to apply to resources"
  type        = map(string)
  default = {
    component  = "dbt"
    managed_by = "terraform"
  }
}

# =============================================================================
# Smoke Test
# =============================================================================

variable "run_smoke_test" {
  description = "Run `gcloud run jobs describe` after creation to verify the job is queryable. Requires gcloud on the apply runner. Default false."
  type        = bool
  default     = false
}

# =============================================================================
# Custom Environment Variables
# =============================================================================

variable "dbt_env_vars" {
  description = "Additional plain (non-secret) env vars to set on the dbt container. Reserved keys (POSTGRES_*, DBT_*) cannot be overridden."
  type        = map(string)
  default     = {}

  validation {
    condition = length([
      for k in keys(var.dbt_env_vars) :
      k if can(regex("^(POSTGRES_.*|DBT_SCHEMA_PREFIX|DBT_TARGET|DBT_COMMAND)$", k))
    ]) == 0
    error_message = "dbt_env_vars cannot override reserved keys: POSTGRES_*, DBT_SCHEMA_PREFIX, DBT_TARGET, DBT_COMMAND. Use the dedicated variables for those."
  }
}

# =============================================================================
# dbt Artifacts (manifest.json, catalog.json) — optional
# =============================================================================

variable "artifacts_bucket_name" {
  description = "Optional GCS bucket name (without gs:// prefix) for dbt to upload target/manifest.json and target/catalog.json after each run. Leave null to disable. The dbt container is responsible for actually uploading; this module only provisions the bucket and IAM."
  type        = string
  default     = null

  validation {
    condition     = var.artifacts_bucket_name == null || can(regex("^[a-z0-9][a-z0-9._-]{1,61}[a-z0-9]$", coalesce(var.artifacts_bucket_name, "x")))
    error_message = "artifacts_bucket_name must be a valid GCS bucket name (lowercase, 3-63 chars, no leading/trailing dots or hyphens)."
  }
}

variable "artifacts_bucket_location" {
  description = "Location for the artifacts bucket (e.g. US, EU, us-central1). Defaults to var.region."
  type        = string
  default     = null
}
