# Consuming gcp-dbt-terraform

This guide documents how to integrate the gcp-dbt-terraform module into your infrastructure as code.

## Module Overview

gcp-dbt-terraform creates a Cloud Run job that executes dbt commands against a PostgreSQL database. It handles VPC networking, secret management, and job scheduling.

## Required Inputs

These inputs must be provided to use this module:

| Input | Type | Description | Example |
|-------|------|-------------|---------|
| `project_id` | string | GCP project ID | `my-project-123` |
| `region` | string | GCP region | `us-central1` |
| `environment` | string | Deployment environment (dev/staging/prod) | `dev` |
| `repo_prefix` | string | Repository name prefix for resource naming | `rag-research-tool` |
| `network_id` | string | VPC network **bare name** (from vpc_egress module) | `rag-vpc` |
| `subnetwork_id` | string | Subnet **bare name** (from vpc_egress module) ⚠️ **See Critical Quirk below** | `rag-subnet` |
| `postgres_host` | string | PostgreSQL internal IP address | `10.0.1.5` |
| `postgres_port` | number | PostgreSQL port (always 5432) | `5432` |
| `postgres_user` | string | Database username | `postgres` |
| `postgres_db` | string | Database name | `myapp_db` |
| `postgres_password_secret` | string | Secret resource ID for password | `projects/PROJECT/secrets/postgres-password` |
| `dbt_image_uri` | string | Docker image location in Artifact Registry | `us-central1-docker.pkg.dev/PROJECT/repo/dbt:latest` |
| `dbt_command` | string | dbt execution command | `dbt run && dbt test` |

## Critical Quirk: Parameter Naming

⚠️ **This module has a naming quirk that confuses many users:**

```hcl
# Parameter name says "id" (suggests resource ID format)
subnetwork_id = module.vpc_egress.subnet_name

# BUT it expects bare subnet_name (NOT subnet_id)
# This works:  module.vpc_egress.subnet_name ✓ (bare name: "rag-subnet")
# This fails:  module.vpc_egress.subnet_id   ✗ (resource ID: "projects/.../subnetworks/...")
```

**Why the naming mismatch?** This module (gcp-dbt-terraform) inherits from an older Cloud Run module that uses non-standard naming. The parameter is called `subnetwork_id`, but Cloud Run expects bare network/subnet names (not resource IDs) for VPC attachment.

## Optional Inputs

These inputs have sensible defaults but can be customized:

| Input | Type | Default | Description |
|-------|------|---------|-------------|
| `memory` | string | `"512Mi"` | Cloud Run memory allocation |
| `cpu` | string | `"1"` | Cloud Run CPU allocation |
| `timeout` | number | `3600` | Job timeout in seconds |
| `max_retries` | number | `0` | Maximum retries on failure |

## Critical Outputs to Re-export

When consuming this module, always re-export these outputs:

### Cloud Run Job Information

```hcl
output "dbt_job_name" {
  description = "Cloud Run job name (for gcloud CLI invocation)"
  value       = module.dbt.job_name
}

output "dbt_job_location" {
  description = "Cloud Run job location (for gcloud CLI invocation)"
  value       = module.dbt.job_location
}
```

**Usage Pattern:**
```bash
# Execute dbt job from gcloud CLI
gcloud run jobs execute $(terraform output -raw dbt_job_name) \
  --region $(terraform output -raw dbt_job_location)
```

## Common Pitfalls

### ❌ Mistake 1: Using subnet_id Instead of subnet_name

**Wrong:**
```hcl
# This will fail silently - Cloud Run cannot attach to subnet
subnetwork_id = module.vpc_egress.subnet_id
```

**Correct:**
```hcl
# Cloud Run needs bare subnet name
subnetwork_id = module.vpc_egress.subnet_name  # "rag-subnet" not "projects/.../subnetworks/rag-subnet"
```

**Why:** Cloud Run uses bare network/subnet names for VPC attachment. The parameter name is misleading (says "id" but expects a name). Always use `subnet_name`, not `subnet_id`.

### ❌ Mistake 2: Hardcoding PostgreSQL Port

**Wrong:**
```hcl
postgres_port = "5432"  # Hardcoded - breaks if module changes default
```

**Correct:**
```hcl
postgres_port = module.postgres.port  # Always references module output
```

**Why:** Port is a module output. Always reference it to ensure consistency if the module changes.

### ❌ Mistake 3: Using Secret Resource Path Directly

**Wrong:**
```hcl
# Passing the full secret path as environment variable
environment = {
  DB_PASSWORD = module.postgres.secrets.password  # resource ID, not the actual secret value
}
```

**Correct:**
```hcl
# Let Cloud Run's secret mounting handle the Secret Manager integration
postgres_password_secret = module.postgres.secrets.password

# Cloud Run will mount this as an environment variable automatically
# The dbt module configures the secret binding
```

**Why:** dbt module expects the **secret resource ID** (full path), not the secret value. The module configures Cloud Run's secret binding to automatically inject the value at runtime.

### ❌ Mistake 4: Not Using Module Outputs for Connection Details

**Wrong:**
```hcl
postgres_host = "10.0.1.5"           # Hardcoded
postgres_user = "postgres"           # Hardcoded
postgres_db   = "myapp_db"           # Hardcoded
```

**Correct:**
```hcl
postgres_host = module.postgres.internal_ip
postgres_user = module.postgres.postgres_db_user
postgres_db   = module.postgres.postgres_db_name
```

**Why:** Module outputs ensure consistency. If PostgreSQL module changes these values, dbt automatically uses the new values.

## Integration Pattern

The dbt module is a **consumer** of both vpc_egress and postgres modules:

```hcl
module "vpc_egress" {
  # VPC module configuration
  # ...
}

module "postgres" {
  # PostgreSQL module configuration
  network_id = module.vpc_egress.vpc_id    # Uses resource ID
  subnet_id  = module.vpc_egress.subnet_id  # Uses resource ID
  # ...
}

module "dbt" {
  # dbt module configuration
  network_id    = module.vpc_egress.vpc_name      # Uses bare name (different from postgres!)
  subnetwork_id = module.vpc_egress.subnet_name   # Uses bare name (not subnet_id)
  
  postgres_host            = module.postgres.internal_ip
  postgres_user            = module.postgres.postgres_db_user
  postgres_db              = module.postgres.postgres_db_name
  postgres_password_secret = module.postgres.secrets.password  # Secret resource ID
  
  dbt_image_uri = var.dbt_image_uri
  dbt_command   = var.dbt_command
}
```

## Integration Example

See [rag-research-tool](https://github.com/DarojaAI/rag_research_tool/blob/main/deploy/terraform/main.tf) for a complete integration example showing:

- VPC module instantiation with bare names
- PostgreSQL module instantiation with resource IDs
- dbt module instantiation consuming both (mixing bare names and resource IDs appropriately)
- Environment variable configuration for dbt
- Job execution patterns in GitHub Actions workflows

## Related Documentation

- [gcp-vpc-egress-terraform](https://github.com/DarojaAI/gcp-vpc-egress-terraform) — VPC module providing vpc_name and subnet_name
- [gcp-postgres-terraform](https://github.com/DarojaAI/gcp-postgres-terraform) — PostgreSQL module providing postgres_host, postgres_db_user, secrets, and internal_ip
- [dbt Documentation](https://docs.getdbt.com/) — dbt project and execution guide
- [Cloud Run VPC Documentation](https://cloud.google.com/run/docs/configuring/connect-vpc) — Official GCP Cloud Run VPC networking guide
