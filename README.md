# terraform-google-dbt-runner

> **Note:** This module is in the process of being renamed from `gcp-dbt-terraform`
> to `terraform-google-dbt-runner` for Terraform Registry compatibility. Until the
> rename ships, use `github.com/DarojaAI/gcp-dbt-terraform` in source URLs.

A reusable Terraform module that provisions a Cloud Run Job for executing dbt
against a private PostgreSQL database on GCP, with direct VPC egress, Workload
Identity Federation for GitHub Actions, and Secret Manager-backed credentials.

## Usage

```hcl
module "dbt_runner" {
  source  = "github.com/DarojaAI/terraform-google-dbt-runner?ref=v1.1.0"

  project_id  = "my-gcp-project"
  environment = "prod"

  network_id    = "projects/my-project/global/networks/my-vpc"
  subnetwork_id = "projects/my-project/regions/us-central1/subnetworks/my-subnet"

  postgres_host            = "10.0.0.2"
  postgres_password_secret = "projects/123/secrets/db-password"

  dbt_image_uri       = "gcr.io/my-project/dbt:latest"
  wif_service_account = "github-actions@my-project.iam.gserviceaccount.com"
}
```

## Architecture

This module wires up:

1. A `google_cloud_run_v2_job` with direct VPC egress (`PRIVATE_RANGES_ONLY`).
2. A dedicated service account `<repo_prefix>-<environment>-dbt-runner`.
3. IAM bindings so the job can read the Postgres password from Secret Manager
   and reach the private subnetwork.
4. A `roles/run.invoker` binding so a Workload-Identity-Federated GitHub
   Actions service account can `gcloud run jobs execute` the job.

The Postgres password is **never** a Terraform variable — pass a Secret Manager
reference and the job pulls it via `value_source.secret_key_ref` at runtime.

## Examples

| Example | Demonstrates |
|---|---|
| [basic](./examples/basic/) | Minimal usage; CI fixture |
| [with-env-vars](./examples/with-env-vars/) | Custom container env vars |
| [with-artifacts-bucket](./examples/with-artifacts-bucket/) | GCS bucket for dbt manifest/catalog |
| [with-failure-notifications](./examples/with-failure-notifications/) | Pub/Sub sink on Cloud Run Job failure |

## Provider configuration

This module does NOT declare a `provider "google"` block — the calling root
module must configure the provider. This is deliberate: a module with its own
provider block can't be used with `count`, `for_each`, or `depends_on`.

## Compatibility

- Terraform: `>= 1.6`
- Google provider: `~> 7.0`

See [VERSIONS.md](./VERSIONS.md) for the full compatibility matrix.

## Releasing

See [RELEASE.md](./RELEASE.md). Briefly: edit the `VERSION` file on `main`,
push, and the `release.yml` workflow tags `vX.Y.Z` and creates a GitHub
Release.

## License

Apache 2.0 — see [LICENSE](./LICENSE).
