# Changelog

All notable changes to this module are documented in this file.

## [Unreleased]

### Added
- `dbt_env_vars` input for arbitrary container env vars
- `job_max_retries` and `job_parallelism` inputs
- Optional GCS artifacts bucket via `artifacts_bucket_name`
- Optional Pub/Sub failure-notification sink via `failure_notification_topic`
- Examples: `with-env-vars`, `with-artifacts-bucket`, `with-failure-notifications`

### Changed
- README rewritten for Terraform Registry compatibility
- Pre-commit checkov hook now scans the repo root instead of a non-existent path

## [1.0.1]
- Use `REPO_PREFIX` env var in `dbt_project.yml` instead of `DBT_SCHEMA_PREFIX` (commit 1763196)
- Validate `dbt_command` to reject shell operators and JSON in `--vars` (commit 7e901e6)
