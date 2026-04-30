# =============================================================================
# Terraform & Provider Configuration
# =============================================================================

terraform {
  required_version = ">= 1.6"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 7.0"
    }
  }
}

# Provider is configured by the consuming root module.
# This allows the module to be used with count, for_each, and depends_on.
