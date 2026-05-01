# gcp-dbt-terraform

Reusable Terraform module for deploying dbt on Google Cloud Platform via Cloud Run Jobs.

**Key Features:**
- ✅ Cloud Run Job for executing dbt migrations and tests
- ✅ VPC egress to access private databases (PostgreSQL VMs on Compute Engine)
- ✅ Service Account with Secret Manager access for database credentials
- ✅ IAM bindings for GitHub Actions WIF authentication
- ✅ Environment-agnostic (works with dev, staging, prod, etc.)
- ✅ Reusable across multiple projects

## Module Structure

```
modules/
  └── dbt-runner/
      ├── main.tf          # Cloud Run Job, Service Account, IAM
      ├── variables.tf     # Input variables
      ├── outputs.tf       # Output values
      └── README.md        # Module documentation

examples/
  ├── basic/               # Minimal example
  └── with-postgres-module/  # Using gcp-postgres-terraform module
```

## Quick Start

```hcl
module "dbt_runner" {
  source = "github.com/DarojaAI/gcp-dbt-terraform//modules/dbt-runner"

  project_id              = "your-project"
  environment             = "eai"
  region                  = "us-central1"

  # Database connection (from PostgreSQL module or hardcoded)
  postgres_host           = "10.0.1.2"
  postgres_port           = 5432
  postgres_db             = "rag_taxonomy"
  postgres_user           = "rag_admin"
  postgres_password_secret = "projects/123/secrets/postgres-password/versions/latest"

  # VPC configuration
  network_id              = "rag-research-eai-vpc"
  subnetwork_id           = "rag-research-eai-subnet"

  # Docker image location
  dbt_image_uri           = "gcr.io/your-project/dbt:latest"

  # WIF service account (GitHub Actions authentication)
  wif_service_account     = "github-actions@your-project.iam.gserviceaccount.com"
}
```

## Docker Image

The dbt Docker image should be built and pushed separately (typically by GitHub Actions).

**Recommended approach:**
1. GitHub Actions builds the image using `Dockerfile.dbt`
2. Pushes to GCR: `gcr.io/{project}/{image}:{tag}`
3. Module references the image URI
4. Cloud Run Job executes with the specified image

This keeps infrastructure (module) separate from CI/CD concerns (GitHub Actions).

## Preflight (recommended for first deploys)

Before your first `terraform apply` against a new project, run:

    bash gcp-dbt-terraform/scripts/preflight.sh \
      --project <your-project> \
      --region <region> \
      --secret <full-secret-path> \
      --subnet <full-subnet-self-link> \
      --wif-sa <wif-sa-email>

Catches API/secret/subnet/IAM errors in seconds rather than minutes after a
failed Cloud Run Job execution. See [`docs/PREFLIGHT.md`](docs/PREFLIGHT.md).

## Integration with gcp-postgres-terraform

Use this module together with [gcp-postgres-terraform](https://github.com/DarojaAI/gcp-postgres-terraform):

```hcl
module "postgres" {
  source = "github.com/DarojaAI/gcp-postgres-terraform//modules/postgres-vm"
  # ... configuration
}

module "dbt_runner" {
  source = "github.com/DarojaAI/gcp-dbt-terraform//modules/dbt-runner"

  postgres_host = module.postgres.internal_ip
  postgres_port = 5432
  # ... other configuration
}
```

## Inputs

See `modules/dbt-runner/variables.tf` for complete list.

Key variables:
- `project_id` — GCP project
- `environment` — Environment name (dev, staging, prod, eai)
- `postgres_*` — Database connection details
- `dbt_image_uri` — Docker image location
- `network_id`, `subnetwork_id` — VPC for database access
- `wif_service_account` — GitHub Actions WIF service account

## Outputs

See `modules/dbt-runner/outputs.tf` for complete list.

Key outputs:
- `job_name` — Cloud Run Job name (use in GitHub Actions)
- `job_location` — Cloud Run Job location
- `service_account_email` — Service account for the job

## GitHub Actions Integration

Trigger the job from GitHub Actions:

```yaml
- name: Execute dbt via Cloud Run Job
  run: |
    gcloud run jobs execute ${{ steps.terraform.outputs.job_name }} \
      --region ${{ vars.REGION }} \
      --project ${{ vars.GCP_PROJECT_ID }} \
      --wait
```

## License

Apache 2.0
