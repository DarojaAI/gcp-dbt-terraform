# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

A reusable Terraform module that provisions a Cloud Run Job for executing dbt against a private PostgreSQL database on GCP. **This repo is consumed by other repos** (e.g. `rag-research-tool`) — it is never deployed standalone. There is no example/, no fixtures, no test harness for the Terraform itself; correctness is enforced by `terraform validate` + `tflint` in CI and by downstream consumers' plans.

The repo also ships two artifacts that downstream projects consume directly from disk:
- `Dockerfile.dbt` — image template; build context is the **calling project's** repo, not this one. The calling project must have a `dbt/` directory.
- `scripts/validate-dbt-docker.sh` — local validation suite, designed to run from the calling project (`bash gcp-dbt-terraform/scripts/validate-dbt-docker.sh`). See `docs/DBT_VALIDATION.md` for the full protocol.

## Architecture: the two-layer module

```
main.tf  (root)  ──►  modules/dbt-runner/  (nested, does the real work)
```

Both layers are publishable sources. Consumers can use either:
- `source = "github.com/DarojaAI/gcp-dbt-terraform"` (root wrapper)
- `source = "github.com/DarojaAI/gcp-dbt-terraform//modules/dbt-runner"` (nested directly)

Root `main.tf` is a thin pass-through: it forwards every variable into `module "dbt_runner"` and re-exports the outputs. **When adding a new variable or output, you must touch four files**: `variables.tf` (root), `main.tf` (root pass-through + output re-export), `modules/dbt-runner/variables.tf`, `modules/dbt-runner/outputs.tf`. Forgetting the root re-export silently breaks consumers using the root source path.

`outputs.tf` at root is intentionally empty — outputs are defined inline in `main.tf` to keep them adjacent to the module block they re-export from. Don't move them.

### Provider configuration is the consumer's responsibility

`versions.tf` declares `required_providers` but no `provider "google"` block. This is deliberate (see commit `881fbc6`): a module with its own provider block can't be used with `count`, `for_each`, or `depends_on`. The calling root module must configure the google provider. Don't add a provider block here.

### Resource naming convention

Every resource is named `${var.repo_prefix}-${var.environment}-...` — the Cloud Run Job, service account, etc. all derive from this pair. `repo_prefix` defaults to `rag-research`, and `environment` is regex-validated to `^[a-z0-9-]+$`. Changing either is a destroy-and-recreate.

### What the module wires up (modules/dbt-runner/main.tf)

1. `google_cloud_run_v2_job` with direct VPC egress (`PRIVATE_RANGES_ONLY`) — no VPC Connector. Network/subnet must be the same VPC as the target Postgres.
2. A dedicated service account `${prefix}-${env}-dbt-runner`.
3. Three IAM bindings on that SA: `secretmanager.secretAccessor` on the postgres password secret, `compute.networkUser` on the subnetwork, and `iam.serviceAccountUser` granted to the WIF SA so GitHub Actions can act-as.
4. `roles/run.invoker` on the job for the WIF SA so Actions can `gcloud run jobs execute`.

The Postgres password is **never** a variable value — `var.postgres_password_secret` is a Secret Manager reference (e.g. `projects/123/secrets/foo/versions/latest`) and the job pulls it via `value_source.secret_key_ref` at runtime.

### `job_id` is parsed, not native

`output "job_id"` does `try(split("/", module.dbt_runner.job_full_name)[5], "")` — the `[5]` is the position of the job ID in `projects/X/locations/Y/jobs/Z`. If a future provider version changes the resource ID format, this output silently returns `""` instead of erroring. See commit `90ed47c` for the rationale.

## Commands

### Local validation (run before pushing)
```powershell
terraform fmt -check -recursive          # CI runs this exact check
terraform init -backend=false            # backend not configured here; consumers configure it
terraform validate
terraform test -verbose                  # plan-time composition tests against examples/basic/
tflint --init --config=.tflint.hcl       # one-time per machine
tflint --config=.tflint.hcl              # google ruleset, version pinned in .tflint.hcl
```

A pre-commit config exists (`.pre-commit-config.yaml`) wiring up `terraform_fmt` and `terraform_validate`. Run `pre-commit install` once, then `pre-commit run --all-files` to execute everything locally.

Checkov and gitleaks run in GitHub Actions (`.github/workflows/security.yml`) rather than as pre-commit hooks. `terraform validate`, `tflint`, and checkov together are the load-bearing checks.

### Validating the Docker image (run from the *calling* project)
```bash
# From the consuming repo (e.g. rag-research-tool/), not from this repo
bash gcp-dbt-terraform/scripts/validate-dbt-docker.sh
```
The script builds `Dockerfile.dbt` against the calling project's context and runs 7 checks (build, `dbt --version`, `dbt parse`, image size, env-var passthrough, pip list, CMD dry-run). Exit codes 1–4 map to specific failure stages — see the script header.

### Releasing

This module uses [release-please](https://github.com/googleapis/release-please) driven by [Conventional Commits](https://www.conventionalcommits.org/).

- Land conventional commits (`feat:`, `fix:`, `feat!:` `refactor!:`) on `main`.
- The `Release Please` workflow opens a release PR that bumps the version, updates `CHANGELOG.md`, and updates `.release-please-manifest.json`.
- Merging the release PR creates the `vX.Y.Z` tag and the GitHub Release.

Consumers pin tags directly: `source = "github.com/DarojaAI/gcp-dbt-terraform?ref=vX.Y.Z"`.

## CI

`.github/workflows/pre-commit.yml` runs on push/PR to main: `terraform fmt -check -recursive`, `terraform validate`, and `tflint`. Terraform pinned to `~1.6`, tflint to `v0.52.0`, google ruleset to `0.39.0` (in `.tflint.hcl`). Match these versions locally to avoid CI surprises.

`.github/workflows/release-please.yml` drives release-please from conventional commits on `main`.

## Feedback-loop tooling

This repo deliberately keeps three layers of validation, each catching a different class of bug at a different speed:

| Layer | Speed | Catches | Run by |
|-------|-------|---------|--------|
| `terraform fmt + validate + tflint` | seconds | syntax, style | CI on every push |
| `terraform test` (against `examples/basic/`) | seconds | module composition, output wiring, four-file-rule mistakes | CI on every push |
| `scripts/preflight.sh` | seconds | API/secret/subnet/IAM env failures | consumer, before first apply |
| `scripts/validate-dbt-docker.sh` | minutes | dbt image build, dbt parse, env var passthrough | consumer, before push |
| `var.run_smoke_test` (in-module probe) | seconds | post-create Cloud Run Job queryability | consumer, opt-in per apply |

When adding a feature: prefer adding a `terraform test` assertion over adding to preflight. When adding a check that requires GCP credentials: add to preflight, not CI. The CI workflow runs without GCP creds — keep it that way.

## Conventions worth knowing

- **Header comment style**: every `.tf` file opens with a `# ===` banner naming the file's purpose. New files should follow.
- **Section banners inside files**: variables and resources are grouped by `# ===` sections (Database Configuration, VPC Configuration, IAM, etc.). Keep new additions inside the matching section.
- **No `terraform.tfvars` in repo**: `.gitignore` excludes `*.tfvars` except `*.tfvars.example` — don't commit values.
- **Defaults are RAG-flavored**: `postgres_db = "rag_taxonomy"`, `postgres_user = "rag_admin"`, `repo_prefix = "rag-research"`. These are project defaults, not generic Terraform conventions — when reviewing PRs that touch defaults, check whether the change is intentional or accidental.
- **Min Terraform / provider versions**: `>= 1.6` and google `~> 7.0`. `VERSIONS.md` is the source of truth for compatibility claims; update it when bumping.
