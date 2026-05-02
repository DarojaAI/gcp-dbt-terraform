# Changelog

All notable changes to this module are documented in this file.

## [Unreleased]

### Added
- `dbt_env_vars` input for arbitrary container env vars
- `job_max_retries` and `job_parallelism` inputs
- Optional GCS artifacts bucket via `artifacts_bucket_name`
- Optional Pub/Sub failure-notification sink via `failure_notification_topic`
- Examples: `with-env-vars`, `with-artifacts-bucket`, `with-failure-notifications`
- README rewritten for Terraform Registry compatibility

### Changed
- Pre-commit hooks reduced to terraform_fmt and terraform_validate; checkov and gitleaks run in GitHub Actions (`.github/workflows/security.yml`) instead

## [1.1.0]

### Fixed
- Use `REPO_PREFIX` env var in `dbt_project.yml` instead of `DBT_SCHEMA_PREFIX`
- Validate `dbt_command` to reject shell operators and JSON in `--vars`
- Run `terraform test` from `examples/basic/` directory in CI
- Initialize `examples/basic/` in CI to avoid null provider error

## [1.0.1]

### Added
- Adopt Terraform standard module structure (root + `modules/dbt-runner/`)
- Automated release workflow triggered by VERSION file changes
- dbt Docker image template (`Dockerfile.dbt`) and validation suite

### Fixed
- Output names corrected to match nested module outputs
- Removed non-existent `vpc_connector_id` output
- Removed duplicate `outputs.tf`
- Derive `job_id` from `job_full_name`

## [1.0.0]

Initial release.
