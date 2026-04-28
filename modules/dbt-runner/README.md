# dbt-runner Module

Terraform module for Cloud Run Job-based dbt execution with VPC access to private databases.

## Overview

This module creates a Cloud Run Job that executes dbt (data build tool) with direct VPC egress to access private PostgreSQL databases running on Compute Engine.

**Key features:**
- ✅ Serverless dbt execution (no persistent infrastructure)
- ✅ Direct VPC access to private databases (no VPC Connector)
- ✅ Automatic Secret Manager integration for credentials
- ✅ GitHub Actions WIF authentication pre-configured
- ✅ Fully managed by Terraform

## Requirements

- Terraform >= 1.6
- Google Cloud Provider >= 5.0
- GCP project with Cloud Run and Secret Manager APIs enabled

## Input Variables

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `project_id` | string | — | GCP project ID |
| `environment` | string | — | Environment name (dev, staging, prod, eai) |
| `region` | string | `us-central1` | GCP region |
| `repo_prefix` | string | `rag-research` | Resource naming prefix |
| `postgres_host` | string | — | Database host (internal VPC IP) |
| `postgres_port` | number | `5432` | Database port |
| `postgres_db` | string | `rag_taxonomy` | Database name |
| `postgres_user` | string | `rag_admin` | Database user |
| `postgres_password_secret` | string | — | Secret Manager secret reference |
| `network_id` | string | — | VPC network resource ID |
| `subnetwork_id` | string | — | VPC subnetwork resource ID |
| `dbt_image_uri` | string | — | Docker image URI (e.g., gcr.io/project/dbt:latest) |
| `dbt_schema_prefix` | string | `rag` | dbt schema prefix |
| `dbt_target` | string | `prod` | dbt target profile |
| `job_timeout_seconds` | number | `1800` | Job timeout (30 minutes) |
| `job_cpu` | string | `2` | CPU allocation |
| `job_memory` | string | `2Gi` | Memory allocation |
| `wif_service_account` | string | — | GitHub Actions WIF service account |
| `labels` | map(string) | `{}` | Resource labels |

## Outputs

| Output | Description |
|--------|-------------|
| `job_name` | Cloud Run Job name |
| `job_location` | Cloud Run Job location |
| `job_full_name` | Full resource name |
| `service_account_email` | Service account email |
| `github_actions_execute_command` | Command to execute job from GitHub Actions |

## Usage

### Basic Example

```hcl
module "dbt_runner" {
  source = "github.com/DarojaAI/gcp-dbt-terraform//modules/dbt-runner"

  project_id              = "my-project"
  environment             = "eai"
  region                  = "us-central1"
  
  postgres_host           = "10.0.1.2"
  postgres_password_secret = "projects/123456/secrets/postgres-password/versions/latest"
  
  network_id   = "rag-research-eai-vpc"
  subnetwork_id = "rag-research-eai-subnet"
  
  dbt_image_uri           = "gcr.io/my-project/dbt:latest"
  wif_service_account     = "github-actions@my-project.iam.gserviceaccount.com"
}
```

### With gcp-postgres-terraform Module

```hcl
module "postgres" {
  source = "github.com/DarojaAI/gcp-postgres-terraform//modules/postgres-vm"
  
  project_id  = "my-project"
  environment = "eai"
  region      = "us-central1"
}

module "dbt_runner" {
  source = "github.com/DarojaAI/gcp-dbt-terraform//modules/dbt-runner"

  project_id              = "my-project"
  environment             = "eai"
  
  postgres_host           = module.postgres.postgres_internal_ip
  postgres_password_secret = module.postgres.postgres_password_secret_id
  
  network_id              = module.postgres.network_id
  subnetwork_id           = module.postgres.subnetwork_id
  
  dbt_image_uri           = "gcr.io/my-project/dbt:latest"
  wif_service_account     = "github-actions@my-project.iam.gserviceaccount.com"
}
```

## GitHub Actions Integration

Once deployed, trigger the dbt job from GitHub Actions:

```yaml
- name: Execute dbt migrations
  run: |
    gcloud run jobs execute ${{ terraform.outputs.job_name }} \
      --region ${{ terraform.outputs.job_location }} \
      --project ${{ vars.GCP_PROJECT_ID }} \
      --wait
```

Or use the pre-generated command:

```yaml
- name: Execute dbt migrations
  run: ${{ terraform.outputs.github_actions_execute_command }}
```

## VPC Access

This module uses **direct VPC egress** to reach private databases:

- No VPC Connector needed (simpler, faster)
- Cloud Run service accesses database via VPC subnet
- Database must be on same VPC as Cloud Run

## Secret Management

Database password is stored in Secret Manager and injected at runtime:

```bash
# Create secret (one-time)
echo -n "your-password" | gcloud secrets create postgres-password --data-file=-

# Grant service account access (done by module)
gcloud secrets add-iam-policy-binding postgres-password \
  --member="serviceAccount:rag-research-eai-dbt-runner@project.iam.gserviceaccount.com" \
  --role="roles/secretmanager.secretAccessor"
```

## Docker Image

The dbt Docker image is not managed by this module. Instead:

1. Build image locally or in GitHub Actions
2. Push to GCR (or your registry)
3. Provide image URI to module: `dbt_image_uri = "gcr.io/project/image:tag"`

Example Dockerfile:
```dockerfile
FROM python:3.12-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install -r requirements.txt
COPY dbt/ ./dbt/
WORKDIR /app/dbt
CMD ["dbt", "run", "--target", "prod"]
```

## Troubleshooting

### Job fails to execute

Check Cloud Run Job logs:
```bash
gcloud run jobs describe rag-research-eai-dbt --region us-central1
gcloud run jobs logs read rag-research-eai-dbt --region us-central1 --limit 50
```

### Cannot connect to database

1. Verify database is on same VPC
2. Check firewall rules allow traffic from Cloud Run region
3. Verify Secret Manager secret is accessible

### Image pull failures

1. Verify image URI is correct
2. Service account has Artifact Registry read access
3. Image exists in registry

## License

Apache 2.0
