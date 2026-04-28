# Version Tracking: gcp-dbt-terraform

## Current Version: 1.0.0

### Module Details
- **Name:** gcp-dbt-terraform
- **Type:** dbt Cloud Run Job Module
- **Status:** Production Ready
- **Repository:** https://github.com/DarojaAI/gcp-dbt-terraform

### Dependencies
| Dependency | Version | Required | Status |
|------------|---------|----------|--------|
| Terraform | >= 1.6 | Yes | ✅ Compatible |
| Google Provider | ~> 7.0 | Yes | ✅ Current |
| gcp-vpc-egress-terraform | >= 1.0.0 | Optional | ℹ️ For VPC access |
| gcp-postgres-terraform | >= 2.0.0 | Optional | ℹ️ For database |

### Terraform Requirements
```hcl
terraform {
  required_version = ">= 1.6"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 7.0"
    }
  }
}
```

### Release History
| Version | Date | Changes | Status |
|---------|------|---------|--------|
| 1.0.0 | 2026-04-28 | Initial release - dbt Cloud Run Jobs | ✅ Released |

### Integration Guide

**Used By:**
- rag-research-tool (for dbt transformations)
- Any GCP project using dbt

**Compatible With:**
- gcp-vpc-egress-terraform (for egress)
- gcp-postgres-terraform (for database access)

**Breaking Changes:** None

### Notes
- Uses google provider 7.0 for compatibility
- Cloud Run Job for scheduled dbt runs
- VPC access for private database connections
