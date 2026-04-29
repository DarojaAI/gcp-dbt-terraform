# =============================================================================
# GCP dbt Runner Module - Root Variables
# =============================================================================

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
  description = "Fully qualified Secret Manager secret reference"
  type        = string
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
  description = "dbt command to run (e.g., 'run', 'test', 'run && test')"
  type        = string
  default     = "run --vars '{\"dbt_schema_prefix\": \"rag\"}' && test --target prod"
}

# =============================================================================
# Cloud Run Job Configuration
# =============================================================================

variable "job_timeout_seconds" {
  description = "Timeout for dbt job execution in seconds"
  type        = number
  default     = 3600
}

variable "job_cpu" {
  description = "CPU allocation for dbt job (e.g., '1' or '2')"
  type        = string
  default     = "2"
}

variable "job_memory" {
  description = "Memory allocation for dbt job (e.g., '1Gi' or '2Gi')"
  type        = string
  default     = "2Gi"
}

variable "job_task_count" {
  description = "Number of tasks to run in parallel"
  type        = number
  default     = 1
}

# =============================================================================
# GitHub Actions Integration
# =============================================================================

variable "wif_service_account" {
  description = "GitHub Actions WIF service account email"
  type        = string
}

# =============================================================================
# Labels
# =============================================================================

variable "labels" {
  description = "GCP labels for all resources"
  type        = map(string)
  default     = {}
}
