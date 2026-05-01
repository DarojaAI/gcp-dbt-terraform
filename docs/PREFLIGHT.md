# Preflight: validate the environment before `terraform apply`

`scripts/preflight.sh` runs read-only `gcloud` checks against your GCP
project to catch IAM, API, secret-format, and region failures before
Terraform creates a Cloud Run Job that cannot execute.

## When to run

- Before the **first** `terraform apply` against a new project/environment
- After rotating the WIF service account or the Postgres password secret
- After moving the Postgres VM to a different subnet

## Run

From the consuming project (the one that imports `gcp-dbt-terraform`):

    bash gcp-dbt-terraform/scripts/preflight.sh \
      --project my-project \
      --region us-central1 \
      --secret projects/123456/secrets/postgres-password/versions/latest \
      --subnet projects/my-project/regions/us-central1/subnetworks/my-subnet \
      --wif-sa github-actions@my-project.iam.gserviceaccount.com

## What it checks

| Check | Why it matters | Exit code on failure |
|-------|----------------|----------------------|
| Required APIs enabled | Cloud Run Job creation 404s if `run.googleapis.com` is off | 2 |
| Secret reference format | Module passes the value raw to `secret_id` — wrong format only fails at apply | 3 |
| Secret exists | Catches typos in the secret path before apply | 3 |
| Subnet exists | A wrong subnet self-link fails apply with a cryptic error | 3 |
| Subnet region matches Cloud Run region | Cloud Run VPC access requires same-region subnet — mismatch fails at job execution time, not apply | 4 |
| WIF SA exists | IAM bindings will succeed against a non-existent SA, then fail when GitHub Actions tries to use it | 3 |

## What it does NOT check

- That the WIF SA can actually invoke the job (chicken-and-egg with the IAM binding the module creates)
- That the dbt Docker image exists in GCR (run `validate-dbt-docker.sh` for image checks)
- That the Postgres VM is reachable from the subnet (network reachability is provider-side)

For image validation, see `docs/DBT_VALIDATION.md`.