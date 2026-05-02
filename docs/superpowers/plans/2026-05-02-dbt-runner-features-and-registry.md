# dbt Runner Module: Feature Additions + Terraform Registry Readiness

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add four functional capabilities to the `dbt-runner` module — pass-through env vars, surfaced job knobs, a manifest/catalog upload bucket, and a failure notification topic — and bring the repo to a state where it can be published on the public Terraform Registry.

**Architecture:** Each feature lands as new optional inputs (default = current behavior, no breaking change). All inputs flow through the four-file rule documented in CLAUDE.md (`variables.tf` root → `main.tf` root pass-through → `modules/dbt-runner/variables.tf` → `modules/dbt-runner/main.tf`/`outputs.tf`). Every feature is gated behind a count/for_each so existing consumers (`rag-research-tool`) see no plan diff after upgrade. Registry readiness is a separate phase covering repo rename, README rewrite, and dead-config removal.

**Tech Stack:** Terraform >= 1.6, Google provider ~> 7.0, Cloud Run Jobs v2, GCS, Eventarc, Pub/Sub, native `terraform test`.

**Backwards-compatibility contract for this plan:** every new variable defaults to a value that produces a zero-resource-diff plan against the current `examples/basic/`. The existing test `tests/basic.tftest.hcl::basic_plan_composes` must continue to pass without modification through Tasks 1–4.

---

## File Structure (read first)

Files touched across all tasks:

| File | Role | Tasks that touch it |
|---|---|---|
| `modules/dbt-runner/variables.tf` | New input declarations | 1, 2, 3, 4 |
| `modules/dbt-runner/main.tf` | New `dynamic` blocks, GCS bucket, Eventarc trigger | 1, 2, 3, 4 |
| `modules/dbt-runner/outputs.tf` | New outputs (artifacts bucket, notification topic) | 3, 4 |
| `variables.tf` (root) | Pass-through declarations | 1, 2, 3, 4 |
| `main.tf` (root) | Pass-through into `module.dbt_runner` + output re-export | 1, 2, 3, 4 |
| `tests/basic.tftest.hcl` | New `run` blocks per feature (each example as its own module source) | 1, 2, 3, 4 |
| `examples/basic/main.tf` | Unchanged (must still compose) | — |
| `examples/with-env-vars/` (NEW) | Demonstrates `dbt_env_vars` | 1 |
| `examples/with-artifacts-bucket/` (NEW) | Demonstrates `artifacts_bucket_name` | 3 |
| `examples/with-failure-notifications/` (NEW) | Demonstrates `failure_notification_topic` | 4 |
| `README.md` (root) | Registry-shaped rewrite | 5 |
| `modules/dbt-runner/README.md` | Submodule README (Registry treats this as externally usable) | 5 |
| `.pre-commit-config.yaml` | Fix dead checkov hook | 5 |
| `CHANGELOG.md` (NEW) | Initial changelog | 5 |
| `.github/workflows/pre-commit.yml` | Add `terraform test` step against new examples | 1, 2, 3, 4 |

**Test strategy:** every feature task adds a `run` block to `tests/basic.tftest.hcl` that points at its own `examples/<scenario>/` directory, so the existing `examples/basic/` plan stays untouched and the four-file rule is exercised on each new variable.

---

## Task 1: Pass-through `dbt_env_vars` map input

**Goal:** Let consumers pass arbitrary `KEY=value` env vars into the dbt container without forking the module or rebuilding the image.

**Files:**
- Modify: `modules/dbt-runner/variables.tf` (append new variable)
- Modify: `modules/dbt-runner/main.tf:18-75` (add `dynamic "env"` block inside `containers`)
- Modify: `variables.tf` (root) (append matching variable)
- Modify: `main.tf` (root) (append pass-through line in `module "dbt_runner"` block)
- Create: `examples/with-env-vars/main.tf`
- Create: `examples/with-env-vars/versions.tf`
- Create: `examples/with-env-vars/README.md`
- Modify: `tests/basic.tftest.hcl` (append `run "with_env_vars_plan"` block)

### Steps

- [ ] **Step 1: Write the failing test**

Append to `tests/basic.tftest.hcl`:

```hcl
run "with_env_vars_plan" {
  command = plan

  module {
    source = "./examples/with-env-vars"
  }

  # Custom env vars must reach the container
  assert {
    condition = anytrue([
      for e in module.dbt_runner.container_env_names :
      e == "DBT_VARS"
    ])
    error_message = "DBT_VARS env var should be present on the dbt container"
  }

  assert {
    condition = anytrue([
      for e in module.dbt_runner.container_env_names :
      e == "ELEMENTARY_PROFILE"
    ])
    error_message = "ELEMENTARY_PROFILE env var should be present on the dbt container"
  }
}
```

This depends on a new output `container_env_names` exposed by Step 3 below. The test will fail before that output exists and before `examples/with-env-vars/` exists.

- [ ] **Step 2: Run test to verify it fails**

Run: `terraform test -verbose -filter=tests/basic.tftest.hcl`
Expected: FAIL — example directory missing and/or output undefined.

- [ ] **Step 3: Add the variable to `modules/dbt-runner/variables.tf`**

Append at end of file (new section):

```hcl
# =============================================================================
# Custom Environment Variables
# =============================================================================

variable "dbt_env_vars" {
  description = "Additional plain (non-secret) env vars to set on the dbt container. Reserved keys (POSTGRES_*, DBT_*) cannot be overridden."
  type        = map(string)
  default     = {}

  validation {
    condition = length([
      for k in keys(var.dbt_env_vars) :
      k if can(regex("^(POSTGRES_.*|DBT_SCHEMA_PREFIX|DBT_TARGET|DBT_COMMAND)$", k))
    ]) == 0
    error_message = "dbt_env_vars cannot override reserved keys: POSTGRES_*, DBT_SCHEMA_PREFIX, DBT_TARGET, DBT_COMMAND. Use the dedicated variables for those."
  }
}
```

- [ ] **Step 4: Wire the variable into the container**

In `modules/dbt-runner/main.tf`, locate the `containers {` block (currently lines 18–75). After the existing `env { name = "DBT_COMMAND" ... }` block (around line 55) and before the `env { name = "POSTGRES_PASSWORD" ... }` block at line 58, add:

```hcl
        # Caller-supplied plain env vars (validated to not collide with reserved keys)
        dynamic "env" {
          for_each = var.dbt_env_vars
          content {
            name  = env.key
            value = env.value
          }
        }
```

- [ ] **Step 5: Add the matching root variable in `variables.tf` (root)**

Append at end of file:

```hcl
# =============================================================================
# Custom Environment Variables (pass-through)
# =============================================================================

variable "dbt_env_vars" {
  description = "Additional plain (non-secret) env vars to set on the dbt container. See modules/dbt-runner/variables.tf for restrictions."
  type        = map(string)
  default     = {}
}
```

- [ ] **Step 6: Wire the pass-through in `main.tf` (root)**

In `main.tf`, inside the `module "dbt_runner" {` block, after the line `run_smoke_test = var.run_smoke_test` (line 54), add:

```hcl

  # Custom env vars
  dbt_env_vars = var.dbt_env_vars
```

- [ ] **Step 7: Add the test-supporting output**

Append to `modules/dbt-runner/outputs.tf`:

```hcl
output "container_env_names" {
  description = "Names of all env vars set on the dbt container — used by terraform test to verify pass-through."
  value       = [for e in google_cloud_run_v2_job.dbt.template[0].template[0].containers[0].env : e.name]
}
```

And re-export at the end of `main.tf` (root):

```hcl
output "container_env_names" {
  description = "Names of all env vars set on the dbt container."
  value       = module.dbt_runner.container_env_names
}
```

- [ ] **Step 8: Create the example fixture**

Create `examples/with-env-vars/main.tf`:

```hcl
# CI fixture: proves dbt_env_vars pass through to the container.
# Never deploy this — every value is a placeholder.

module "dbt_runner" {
  source = "../.."

  project_id  = "fake-project"
  environment = "ci"
  region      = "us-central1"
  repo_prefix = "rag-research"

  network_id    = "projects/fake-project/global/networks/fake-vpc"
  subnetwork_id = "projects/fake-project/regions/us-central1/subnetworks/fake-subnet"

  # checkov:skip=CKV_SECRET_6: This is a fake/test placeholder, not a real secret
  postgres_host            = "10.0.0.2"
  postgres_port            = 5432
  postgres_db              = "rag_taxonomy"
  postgres_user            = "rag_admin"
  postgres_password_secret = "projects/000000000000/secrets/fake-postgres-password/versions/latest"

  dbt_image_uri       = "gcr.io/fake-project/dbt:latest"
  wif_service_account = "github-actions@fake-project.iam.gserviceaccount.com"

  dbt_env_vars = {
    DBT_VARS           = "key1=val1,key2=val2"
    ELEMENTARY_PROFILE = "default"
  }
}
```

Create `examples/with-env-vars/versions.tf`:

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

provider "google" {
  project = "fake-project-for-plan-only"
  region  = "us-central1"
}
```

Create `examples/with-env-vars/README.md`:

```markdown
# Example: dbt Runner with custom env vars

Demonstrates `dbt_env_vars` for passing additional plain (non-secret) environment
variables into the dbt container without rebuilding the image.

This example is fixture-only — values are placeholders. Run via:

```bash
terraform init
terraform plan
```
```

- [ ] **Step 9: Run all tests to verify pass**

Run: `terraform test -verbose`
Expected: both `basic_plan_composes` and `with_env_vars_plan` PASS.

- [ ] **Step 10: Run formatter and linter**

```bash
terraform fmt -check -recursive
tflint --config=.tflint.hcl
```
Expected: clean exit (no diff, no findings).

- [ ] **Step 11: Commit**

```bash
git add modules/dbt-runner/variables.tf modules/dbt-runner/main.tf modules/dbt-runner/outputs.tf \
        variables.tf main.tf \
        examples/with-env-vars/ \
        tests/basic.tftest.hcl
git commit -m "feat: add dbt_env_vars pass-through for arbitrary container env vars"
```

---

## Task 2: Surface job timeout / retry / parallelism knobs

**Goal:** `job_timeout_seconds`, `job_cpu`, `job_memory`, `job_task_count` already exist. Add `max_retries` and `parallelism` (currently hardcoded to 0 and 1 respectively in `modules/dbt-runner/main.tf:12,89`).

**Files:**
- Modify: `modules/dbt-runner/variables.tf`
- Modify: `modules/dbt-runner/main.tf:11-13` (parallelism), `:89` (max_retries)
- Modify: `variables.tf` (root)
- Modify: `main.tf` (root)
- Modify: `tests/basic.tftest.hcl` (extend `basic_plan_composes` with new asserts on defaults)

### Steps

- [ ] **Step 1: Write the failing test**

Append two assertions inside the existing `run "basic_plan_composes"` block in `tests/basic.tftest.hcl`:

```hcl
  # Defaults: max_retries = 0 (matches current hardcoded behavior)
  assert {
    condition     = module.dbt_runner.max_retries == 0
    error_message = "max_retries default must remain 0 (no behavior change)"
  }

  # Defaults: parallelism = 1
  assert {
    condition     = module.dbt_runner.parallelism == 1
    error_message = "parallelism default must remain 1 (no behavior change)"
  }
```

- [ ] **Step 2: Run test to verify it fails**

Run: `terraform test -verbose`
Expected: FAIL — outputs `max_retries` and `parallelism` not yet defined.

- [ ] **Step 3: Add new variables to `modules/dbt-runner/variables.tf`**

In the `# Cloud Run Job Configuration` section, after `variable "job_task_count"` (line 144–148), append:

```hcl
variable "job_max_retries" {
  description = "Number of retries for a failed Cloud Run Job task. Default 0 (no retries) preserves current behavior; raise to 1–3 only if the dbt job is idempotent on partial failure."
  type        = number
  default     = 0

  validation {
    condition     = var.job_max_retries >= 0 && var.job_max_retries <= 10
    error_message = "job_max_retries must be between 0 and 10 (Cloud Run hard limit)."
  }
}

variable "job_parallelism" {
  description = "Number of tasks that may run in parallel. Must be <= job_task_count. dbt is generally not safe to run in parallel against the same warehouse — leave at 1 unless you know what you're doing."
  type        = number
  default     = 1
}
```

- [ ] **Step 4: Wire the variables into the resource**

In `modules/dbt-runner/main.tf`:

- Replace line 12 (`parallelism = 1`) with:
  ```hcl
      parallelism = var.job_parallelism
  ```
- Replace line 89 (`max_retries = 0`) with:
  ```hcl
        max_retries = var.job_max_retries
  ```

- [ ] **Step 5: Add the test-supporting outputs**

Append to `modules/dbt-runner/outputs.tf`:

```hcl
output "max_retries" {
  description = "Resolved max_retries on the Cloud Run Job — used by terraform test."
  value       = google_cloud_run_v2_job.dbt.template[0].template[0].max_retries
}

output "parallelism" {
  description = "Resolved parallelism on the Cloud Run Job — used by terraform test."
  value       = google_cloud_run_v2_job.dbt.template[0].parallelism
}
```

And re-export at the end of `main.tf` (root):

```hcl
output "max_retries" {
  description = "Resolved max_retries on the Cloud Run Job."
  value       = module.dbt_runner.max_retries
}

output "parallelism" {
  description = "Resolved parallelism on the Cloud Run Job."
  value       = module.dbt_runner.parallelism
}
```

- [ ] **Step 6: Pass-through in root `variables.tf`**

Append at end of file:

```hcl
variable "job_max_retries" {
  description = "Number of retries for a failed Cloud Run Job task. Default 0 (no retries)."
  type        = number
  default     = 0
}

variable "job_parallelism" {
  description = "Number of tasks that may run in parallel. Must be <= job_task_count."
  type        = number
  default     = 1
}
```

- [ ] **Step 7: Pass-through in root `main.tf`**

Inside the `module "dbt_runner" {` block, after `job_task_count = var.job_task_count`, add:

```hcl
  job_max_retries = var.job_max_retries
  job_parallelism = var.job_parallelism
```

- [ ] **Step 8: Run all tests**

Run: `terraform test -verbose`
Expected: PASS for `basic_plan_composes` (with two new assertions) and `with_env_vars_plan`.

- [ ] **Step 9: Run formatter and linter**

```bash
terraform fmt -check -recursive
tflint --config=.tflint.hcl
```

- [ ] **Step 10: Commit**

```bash
git add modules/dbt-runner/variables.tf modules/dbt-runner/main.tf modules/dbt-runner/outputs.tf \
        variables.tf main.tf tests/basic.tftest.hcl
git commit -m "feat: surface job_max_retries and job_parallelism (preserves defaults)"
```

---

## Task 3: Optional GCS bucket for dbt artifacts (manifest, catalog)

**Goal:** When `var.artifacts_bucket_name != null`, create a regional GCS bucket and grant the dbt service account `roles/storage.objectAdmin` on it. The dbt container is responsible for actually `gsutil cp`-ing `target/manifest.json` into it (out of module scope) — the module just provisions the destination + IAM. When the variable is null, no bucket is created and existing consumers see zero diff.

**Files:**
- Modify: `modules/dbt-runner/variables.tf`
- Modify: `modules/dbt-runner/main.tf` (new resources at end of file)
- Modify: `modules/dbt-runner/outputs.tf`
- Modify: `variables.tf` (root)
- Modify: `main.tf` (root)
- Create: `examples/with-artifacts-bucket/main.tf`
- Create: `examples/with-artifacts-bucket/versions.tf`
- Create: `examples/with-artifacts-bucket/README.md`
- Modify: `tests/basic.tftest.hcl`

### Steps

- [ ] **Step 1: Write the failing test**

Append to `tests/basic.tftest.hcl`:

```hcl
run "with_artifacts_bucket_plan" {
  command = plan

  module {
    source = "./examples/with-artifacts-bucket"
  }

  # Bucket name is propagated to output
  assert {
    condition     = module.dbt_runner.artifacts_bucket_name == "fake-rag-research-ci-dbt-artifacts"
    error_message = "artifacts_bucket_name should match the input"
  }

  # Container env exposes the bucket so dbt can write to it
  assert {
    condition = anytrue([
      for e in module.dbt_runner.container_env_names :
      e == "DBT_ARTIFACTS_BUCKET"
    ])
    error_message = "DBT_ARTIFACTS_BUCKET env var should be present when artifacts_bucket_name is set"
  }
}

run "no_artifacts_bucket_default" {
  command = plan

  module {
    source = "./examples/basic"
  }

  # When unset, output is null
  assert {
    condition     = module.dbt_runner.artifacts_bucket_name == null
    error_message = "artifacts_bucket_name should be null when no bucket is configured"
  }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `terraform test -verbose`
Expected: FAIL — example missing, output undefined.

- [ ] **Step 3: Add the variable to `modules/dbt-runner/variables.tf`**

Append at end of file:

```hcl
# =============================================================================
# dbt Artifacts (manifest.json, catalog.json) — optional
# =============================================================================

variable "artifacts_bucket_name" {
  description = "Optional GCS bucket name (without gs:// prefix) for dbt to upload target/manifest.json and target/catalog.json after each run. Leave null to disable. The dbt container is responsible for actually uploading; this module only provisions the bucket and IAM."
  type        = string
  default     = null

  validation {
    condition     = var.artifacts_bucket_name == null || can(regex("^[a-z0-9][a-z0-9._-]{1,61}[a-z0-9]$", coalesce(var.artifacts_bucket_name, "x")))
    error_message = "artifacts_bucket_name must be a valid GCS bucket name (lowercase, 3-63 chars, no leading/trailing dots or hyphens)."
  }
}

variable "artifacts_bucket_location" {
  description = "Location for the artifacts bucket (e.g. US, EU, us-central1). Defaults to var.region."
  type        = string
  default     = null
}
```

- [ ] **Step 4: Add the resources to `modules/dbt-runner/main.tf`**

Append at end of file:

```hcl
# =============================================================================
# dbt Artifacts Bucket — optional, created only when artifacts_bucket_name set
# =============================================================================

locals {
  artifacts_enabled = var.artifacts_bucket_name != null
}

resource "google_storage_bucket" "artifacts" {
  count = local.artifacts_enabled ? 1 : 0

  project       = var.project_id
  name          = var.artifacts_bucket_name
  location      = coalesce(var.artifacts_bucket_location, var.region)
  force_destroy = false
  labels        = var.labels

  uniform_bucket_level_access = true

  versioning {
    enabled = true
  }

  lifecycle_rule {
    condition {
      age        = 90
      with_state = "ARCHIVED"
    }
    action {
      type = "Delete"
    }
  }
}

resource "google_storage_bucket_iam_member" "dbt_artifacts_writer" {
  count = local.artifacts_enabled ? 1 : 0

  bucket = google_storage_bucket.artifacts[0].name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.dbt_runner.email}"
}
```

- [ ] **Step 5: Inject the bucket name into the container env**

In `modules/dbt-runner/main.tf`, inside the `containers {` block, after the `dynamic "env"` block added in Task 1, add:

```hcl
        dynamic "env" {
          for_each = local.artifacts_enabled ? [1] : []
          content {
            name  = "DBT_ARTIFACTS_BUCKET"
            value = google_storage_bucket.artifacts[0].name
          }
        }
```

- [ ] **Step 6: Add outputs**

Append to `modules/dbt-runner/outputs.tf`:

```hcl
output "artifacts_bucket_name" {
  description = "GCS bucket name for dbt artifacts (null if disabled)."
  value       = local.artifacts_enabled ? google_storage_bucket.artifacts[0].name : null
}

output "artifacts_bucket_url" {
  description = "gs:// URL of the dbt artifacts bucket (null if disabled)."
  value       = local.artifacts_enabled ? google_storage_bucket.artifacts[0].url : null
}
```

Re-export at the end of `main.tf` (root):

```hcl
output "artifacts_bucket_name" {
  description = "GCS bucket name for dbt artifacts (null if disabled)."
  value       = module.dbt_runner.artifacts_bucket_name
}

output "artifacts_bucket_url" {
  description = "gs:// URL of the dbt artifacts bucket (null if disabled)."
  value       = module.dbt_runner.artifacts_bucket_url
}
```

- [ ] **Step 7: Pass-through in root `variables.tf`**

Append at end of file:

```hcl
variable "artifacts_bucket_name" {
  description = "Optional GCS bucket for dbt artifacts. Leave null to disable."
  type        = string
  default     = null
}

variable "artifacts_bucket_location" {
  description = "Location for the artifacts bucket. Defaults to var.region."
  type        = string
  default     = null
}
```

- [ ] **Step 8: Pass-through in root `main.tf`**

Inside the `module "dbt_runner" {` block, append:

```hcl
  artifacts_bucket_name     = var.artifacts_bucket_name
  artifacts_bucket_location = var.artifacts_bucket_location
```

- [ ] **Step 9: Create the example fixture**

Create `examples/with-artifacts-bucket/main.tf`:

```hcl
# CI fixture: proves the artifacts bucket and IAM are wired correctly.

module "dbt_runner" {
  source = "../.."

  project_id  = "fake-project"
  environment = "ci"
  region      = "us-central1"
  repo_prefix = "rag-research"

  network_id    = "projects/fake-project/global/networks/fake-vpc"
  subnetwork_id = "projects/fake-project/regions/us-central1/subnetworks/fake-subnet"

  # checkov:skip=CKV_SECRET_6: This is a fake/test placeholder, not a real secret
  postgres_host            = "10.0.0.2"
  postgres_port            = 5432
  postgres_db              = "rag_taxonomy"
  postgres_user            = "rag_admin"
  postgres_password_secret = "projects/000000000000/secrets/fake-postgres-password/versions/latest"

  dbt_image_uri       = "gcr.io/fake-project/dbt:latest"
  wif_service_account = "github-actions@fake-project.iam.gserviceaccount.com"

  artifacts_bucket_name     = "fake-rag-research-ci-dbt-artifacts"
  artifacts_bucket_location = "US"
}
```

Create `examples/with-artifacts-bucket/versions.tf` (identical to `examples/basic/versions.tf`):

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

provider "google" {
  project = "fake-project-for-plan-only"
  region  = "us-central1"
}
```

Create `examples/with-artifacts-bucket/README.md`:

```markdown
# Example: dbt Runner with artifacts bucket

Demonstrates the optional GCS bucket for `target/manifest.json` and
`target/catalog.json`. The dbt container must `gsutil cp` to
`gs://$DBT_ARTIFACTS_BUCKET/` after each run — this module only provisions
the bucket and grants the runner service account `storage.objectAdmin`.

Fixture-only. Values are placeholders.
```

- [ ] **Step 10: Run all tests**

Run: `terraform test -verbose`
Expected: all four `run` blocks PASS.

- [ ] **Step 11: Format + lint**

```bash
terraform fmt -check -recursive
tflint --config=.tflint.hcl
```

- [ ] **Step 12: Commit**

```bash
git add modules/dbt-runner/variables.tf modules/dbt-runner/main.tf modules/dbt-runner/outputs.tf \
        variables.tf main.tf \
        examples/with-artifacts-bucket/ \
        tests/basic.tftest.hcl
git commit -m "feat: optional GCS bucket for dbt manifest/catalog artifacts"
```

---

## Task 4: Optional Pub/Sub failure-notification topic

**Goal:** When `var.failure_notification_topic != null`, create an Eventarc trigger that publishes Cloud Run Job execution-failure events to the named Pub/Sub topic. The topic itself must already exist (consumer creates it; module just wires the trigger). When null, no trigger is created.

**Files:**
- Modify: `modules/dbt-runner/variables.tf`
- Modify: `modules/dbt-runner/main.tf` (new resource block at end)
- Modify: `modules/dbt-runner/outputs.tf`
- Modify: `variables.tf` (root)
- Modify: `main.tf` (root)
- Create: `examples/with-failure-notifications/main.tf`
- Create: `examples/with-failure-notifications/versions.tf`
- Create: `examples/with-failure-notifications/README.md`
- Modify: `tests/basic.tftest.hcl`

### Steps

- [ ] **Step 1: Write the failing test**

Append to `tests/basic.tftest.hcl`:

```hcl
run "with_failure_notifications_plan" {
  command = plan

  module {
    source = "./examples/with-failure-notifications"
  }

  assert {
    condition     = module.dbt_runner.failure_notification_topic == "projects/fake-project/topics/dbt-failures"
    error_message = "failure_notification_topic output should match input"
  }

  assert {
    condition     = module.dbt_runner.failure_notification_trigger_id != null
    error_message = "Eventarc trigger ID should be set when failure_notification_topic is configured"
  }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `terraform test -verbose`
Expected: FAIL.

- [ ] **Step 3: Add the variable to `modules/dbt-runner/variables.tf`**

Append at end of file:

```hcl
# =============================================================================
# Failure Notifications — optional
# =============================================================================

variable "failure_notification_topic" {
  description = "Optional fully-qualified Pub/Sub topic (projects/PROJECT/topics/NAME) to receive Cloud Run Job execution-failure events via Eventarc. The topic must already exist; this module only wires the trigger. Leave null to disable."
  type        = string
  default     = null

  validation {
    condition     = var.failure_notification_topic == null || can(regex("^projects/[^/]+/topics/[^/]+$", coalesce(var.failure_notification_topic, "projects/x/topics/x")))
    error_message = "failure_notification_topic must be in the form 'projects/PROJECT/topics/NAME'."
  }
}
```

- [ ] **Step 4: Add the Eventarc trigger to `modules/dbt-runner/main.tf`**

Append at end of file:

```hcl
# =============================================================================
# Failure Notifications — optional Eventarc trigger to a Pub/Sub topic
# =============================================================================

locals {
  failure_notifications_enabled = var.failure_notification_topic != null
}

resource "google_eventarc_trigger" "job_failure" {
  count = local.failure_notifications_enabled ? 1 : 0

  project  = var.project_id
  name     = "${var.repo_prefix}-${var.environment}-dbt-failure"
  location = var.region

  matching_criteria {
    attribute = "type"
    value     = "google.cloud.audit.log.v1.written"
  }
  matching_criteria {
    attribute = "serviceName"
    value     = "run.googleapis.com"
  }
  matching_criteria {
    attribute = "methodName"
    value     = "google.cloud.run.v2.Executions.RunJob"
  }

  destination {
    cloud_run_service {
      # Eventarc requires a destination; using pubsub topic as transport target via gcs sink is not supported,
      # so we route through pubsub by setting transport.pubsub.topic and a no-op cloud_run_service is omitted.
      # Instead, use destination.workflow OR destination.cloud_run_service. For a topic-only sink we use transport.
    }
  }

  transport {
    pubsub {
      topic = var.failure_notification_topic
    }
  }

  service_account = google_service_account.dbt_runner.email

  labels = var.labels
}
```

> **Important note for the implementer:** The `destination {}` block in Eventarc is required by the provider schema but cannot point at a Pub/Sub topic directly — Eventarc treats Pub/Sub as a *transport*, not a destination. Before committing this step, verify the actual provider schema with `terraform providers schema -json | jq '.provider_schemas."registry.terraform.io/hashicorp/google".resource_schemas.google_eventarc_trigger'`. If the schema rejects the trigger as written, fall back to the simpler approach: use `google_logging_project_sink` filtered on Cloud Run Job failure log entries, with the pubsub topic as the sink destination. That is the documented pattern for "Pub/Sub on Cloud Run Job failure" and avoids the Eventarc destination quirk. Replace the entire `google_eventarc_trigger` block above with:
>
> ```hcl
> resource "google_logging_project_sink" "job_failure" {
>   count = local.failure_notifications_enabled ? 1 : 0
>
>   project     = var.project_id
>   name        = "${var.repo_prefix}-${var.environment}-dbt-failure-sink"
>   destination = "pubsub.googleapis.com/${var.failure_notification_topic}"
>
>   filter = join(" AND ", [
>     "resource.type=\"cloud_run_job\"",
>     "resource.labels.job_name=\"${google_cloud_run_v2_job.dbt.name}\"",
>     "severity>=ERROR",
>   ])
>
>   unique_writer_identity = true
> }
>
> resource "google_pubsub_topic_iam_member" "log_sink_publisher" {
>   count = local.failure_notifications_enabled ? 1 : 0
>
>   project = var.project_id
>   topic   = element(split("/", var.failure_notification_topic), 3)
>   role    = "roles/pubsub.publisher"
>   member  = google_logging_project_sink.job_failure[0].writer_identity
> }
> ```
>
> Update outputs in Step 5 accordingly: replace `google_eventarc_trigger.job_failure[0].id` with `google_logging_project_sink.job_failure[0].id`.

- [ ] **Step 5: Add outputs**

Append to `modules/dbt-runner/outputs.tf`:

```hcl
output "failure_notification_topic" {
  description = "Pub/Sub topic that receives Cloud Run Job failure events (null if disabled)."
  value       = var.failure_notification_topic
}

output "failure_notification_trigger_id" {
  description = "ID of the resource wiring failures to the Pub/Sub topic (null if disabled)."
  value       = local.failure_notifications_enabled ? google_logging_project_sink.job_failure[0].id : null
}
```

Re-export in root `main.tf`:

```hcl
output "failure_notification_topic" {
  description = "Pub/Sub topic for Cloud Run Job failure events (null if disabled)."
  value       = module.dbt_runner.failure_notification_topic
}

output "failure_notification_trigger_id" {
  description = "ID of the failure-notification trigger (null if disabled)."
  value       = module.dbt_runner.failure_notification_trigger_id
}
```

- [ ] **Step 6: Pass-through in root `variables.tf`**

Append:

```hcl
variable "failure_notification_topic" {
  description = "Optional Pub/Sub topic to receive Cloud Run Job failure events. Leave null to disable."
  type        = string
  default     = null
}
```

- [ ] **Step 7: Pass-through in root `main.tf`**

Inside the `module "dbt_runner" {` block, append:

```hcl
  failure_notification_topic = var.failure_notification_topic
```

- [ ] **Step 8: Create the example fixture**

Create `examples/with-failure-notifications/main.tf`:

```hcl
module "dbt_runner" {
  source = "../.."

  project_id  = "fake-project"
  environment = "ci"
  region      = "us-central1"
  repo_prefix = "rag-research"

  network_id    = "projects/fake-project/global/networks/fake-vpc"
  subnetwork_id = "projects/fake-project/regions/us-central1/subnetworks/fake-subnet"

  # checkov:skip=CKV_SECRET_6: This is a fake/test placeholder, not a real secret
  postgres_host            = "10.0.0.2"
  postgres_port            = 5432
  postgres_db              = "rag_taxonomy"
  postgres_user            = "rag_admin"
  postgres_password_secret = "projects/000000000000/secrets/fake-postgres-password/versions/latest"

  dbt_image_uri       = "gcr.io/fake-project/dbt:latest"
  wif_service_account = "github-actions@fake-project.iam.gserviceaccount.com"

  failure_notification_topic = "projects/fake-project/topics/dbt-failures"
}
```

Create `examples/with-failure-notifications/versions.tf` (identical to other examples).

Create `examples/with-failure-notifications/README.md`:

```markdown
# Example: dbt Runner with failure notifications

Demonstrates wiring Cloud Run Job execution failures to a Pub/Sub topic via a
log-based sink. The Pub/Sub topic must already exist — the module grants the
sink's writer identity `roles/pubsub.publisher` on it.

Fixture-only. Values are placeholders.
```

- [ ] **Step 9: Run all tests**

Run: `terraform test -verbose`
Expected: all `run` blocks PASS.

- [ ] **Step 10: Format + lint**

```bash
terraform fmt -check -recursive
tflint --config=.tflint.hcl
```

- [ ] **Step 11: Commit**

```bash
git add modules/dbt-runner/variables.tf modules/dbt-runner/main.tf modules/dbt-runner/outputs.tf \
        variables.tf main.tf \
        examples/with-failure-notifications/ \
        tests/basic.tftest.hcl
git commit -m "feat: optional log-based Pub/Sub sink for Cloud Run Job failures"
```

---

## Task 5: Terraform Registry readiness

**Goal:** Bring the repo to a state where it can be published on the public Terraform Registry. Per HashiCorp's standards (https://developer.hashicorp.com/terraform/registry/modules/publish and the linked standard module structure):

- Repo name MUST be `terraform-<PROVIDER>-<NAME>` — currently `gcp-dbt-terraform`. Target: `terraform-google-dbt-runner`.
- Repo MUST be public on GitHub.
- README at root MUST describe the module, show example usage, and (recommended) include a diagram.
- LICENSE MUST be present (already done — Apache 2.0).
- Each nested module under `modules/` with a README is treated as externally usable; the existing `modules/dbt-runner/README.md` is fine, but its `source = ` examples MUST point at external addresses, not relative paths (https://developer.hashicorp.com/terraform/language/modules/develop/structure).
- Each example under `examples/` SHOULD have a README — Tasks 1, 3, 4 already added these; verify `examples/basic/README.md` exists.
- Tags MUST be semantic versions (`vX.Y.Z`). Current `release.yml` already does this — leave it.

**Files:**
- Modify: `README.md` (root) — full rewrite
- Modify: `modules/dbt-runner/README.md` — fix source examples
- Modify: `examples/basic/README.md` — verify present, expand if thin
- Modify: `.pre-commit-config.yaml` — fix or remove the dead checkov hook (CLAUDE.md notes it points at non-existent `terraform/`)
- Create: `CHANGELOG.md` — single seed entry for current state
- Modify: `CLAUDE.md` — update the "checkov hook is currently a no-op" note once fixed

### Steps

- [ ] **Step 1: Audit the current README**

Read `README.md`. Verify it covers (per registry expectations):
1. One-paragraph description matching the GitHub repo description
2. A "Usage" section with a copy-paste example using the external `source = "github.com/..."` form (not `./modules/...`)
3. Inputs and outputs sections (auto-generated by `terraform-docs` is fine — pre-commit already runs it)
4. A reference to each example under `examples/`
5. License section

Note any gaps as TODO comments inside the file. Do not commit.

- [ ] **Step 2: Rewrite root README**

Overwrite `README.md` with the following structure. Replace `<TBD>` markers with values from your repo state. Keep length under ~200 lines:

```markdown
# terraform-google-dbt-runner

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
```

- [ ] **Step 3: Fix `modules/dbt-runner/README.md` source examples**

Read `modules/dbt-runner/README.md`. Find every `source = "./..."` or `source = "../..."` example and replace with the external form:

```hcl
source  = "github.com/DarojaAI/terraform-google-dbt-runner//modules/dbt-runner?ref=v1.1.0"
```

This is the registry rule: nested-module READMEs must use external addresses, not relative paths.

- [ ] **Step 4: Verify `examples/basic/README.md`**

Read `examples/basic/README.md`. If absent or under 5 lines, replace with:

```markdown
# Example: basic dbt Runner

Minimal `dbt_runner` invocation used as a CI fixture for `terraform test`.
Every input is a placeholder — never apply this. The fake provider config
lets `terraform plan` run without GCP credentials.

```bash
terraform init
terraform plan
```
```

- [ ] **Step 5: Fix the dead checkov pre-commit hook**

Read `.pre-commit-config.yaml`. Locate the checkov hook with `--directory terraform/`. Replace the args with:

```yaml
        args:
          - --directory
          - .
          - --skip-path
          - examples/
          - --quiet
```

Skipping `examples/` keeps fixture placeholders (fake secrets, fake bucket names) from triggering false positives.

- [ ] **Step 6: Run pre-commit locally to confirm checkov no longer no-ops**

```bash
pre-commit run --all-files
```
Expected: checkov runs (output visible), all hooks pass.

- [ ] **Step 7: Update CLAUDE.md note about checkov**

In `CLAUDE.md`, find the paragraph that says "Note: the checkov hook is configured with `--directory terraform/` which **does not exist in this repo**". Replace with:

```markdown
Checkov runs against the repo root with `examples/` skipped (fixture placeholders would otherwise produce false positives).
```

- [ ] **Step 8: Create CHANGELOG.md**

Create `CHANGELOG.md`:

```markdown
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

## [1.0.1] - earlier
- Use `REPO_PREFIX` env var in `dbt_project.yml` instead of `DBT_SCHEMA_PREFIX` (commit 1763196)
- Validate `dbt_command` to reject shell operators and JSON in `--vars` (commit 7e901e6)
```

- [ ] **Step 9: Run the full validation chain**

```bash
terraform fmt -check -recursive
terraform validate
terraform test -verbose
tflint --config=.tflint.hcl
pre-commit run --all-files
```
Expected: all green.

- [ ] **Step 10: Commit Registry-readiness changes**

```bash
git add README.md modules/dbt-runner/README.md examples/basic/README.md \
        .pre-commit-config.yaml CLAUDE.md CHANGELOG.md
git commit -m "docs: prepare module for Terraform Registry publication"
```

- [ ] **Step 11: Repo rename — manual coordination required**

This step CANNOT be done from this plan; it requires GitHub admin access and breaks every existing consumer's `source = "github.com/DarojaAI/gcp-dbt-terraform"`. Do not execute without explicit user approval and a coordinated migration window.

When approved:

1. On GitHub: Settings → rename repo from `gcp-dbt-terraform` to `terraform-google-dbt-runner`. GitHub will set up an automatic redirect for the old name, but **module sources that include a SHA or ref still resolve via the new name** — consumers must still update their `source = ` strings to avoid future breakage.
2. Update CLAUDE.md references to the old name.
3. Notify consumers (`rag-research-tool` is named in CLAUDE.md) — they'll need to update their `source = "github.com/DarojaAI/..."` and re-run `terraform init -upgrade`.
4. Bump VERSION to `1.1.0` (minor — additive features) and let `release.yml` tag.
5. Publish on the Terraform Registry: https://registry.terraform.io/github/create — sign in, select the renamed repo, confirm.

---

## Self-Review

**Spec coverage:**
- ✅ Task 1 — env-vars pass-through (concept #1 from prior turn)
- ✅ Task 2 — job knobs (concept #2)
- ✅ Task 3 — artifacts bucket (concept #5 / "biggest functional gap")
- ✅ Task 4 — failure notifications (concept #3)
- ✅ Task 5 — Registry readiness: repo name (rename note in 5.11), README, LICENSE (already present), examples, tags (already correct), nested-module README source format

**Placeholder scan:** Step 4 of Task 4 contains a `<TBD>`-style fork ("if the schema rejects the Eventarc form, fall back to log sink"). This is intentional, not a placeholder — both code paths are fully written so the implementer can pick the one the provider accepts. The `<TBD>` markers in the README template (Task 5 Step 2) refer to fields the implementer fills from their actual repo (e.g. ref tags). Acceptable.

**Type consistency:**
- `container_env_names` (output) used in Task 1 Step 1, defined in Task 1 Step 7. ✅
- `max_retries`, `parallelism` outputs used in Task 2 Step 1, defined in Task 2 Step 5. ✅
- `artifacts_bucket_name`, `artifacts_bucket_url` used in Task 3 Step 1, defined in Step 6. ✅
- `failure_notification_topic`, `failure_notification_trigger_id` used in Task 4 Step 1, defined in Step 5. ✅
- `local.artifacts_enabled` defined in Task 3 Step 4, used in Step 5 (env injection) and Step 6 (outputs). ✅
- `local.failure_notifications_enabled` defined in Task 4 Step 4, used in Step 5 (outputs). ✅

**Backwards-compat invariant check:** every new variable defaults to a value that produces zero new resources (`null`, `0`, `1`, `{}`). The `examples/basic/` fixture is unchanged across Tasks 1–4, so the existing `basic_plan_composes` test remains the canonical regression check.

**Four-file rule check:** every variable touches `modules/dbt-runner/variables.tf`, `modules/dbt-runner/main.tf` (or `outputs.tf`), `variables.tf` (root), and `main.tf` (root). ✅

---

## Execution Handoff

Plan complete and saved to `docs/superpowers/plans/2026-05-02-dbt-runner-features-and-registry.md`. Two execution options:

**1. Subagent-Driven (recommended)** — fresh subagent per task, review between tasks, fast iteration.

**2. Inline Execution** — execute tasks in this session using executing-plans, batch execution with checkpoints.

Note: Task 5 Step 11 (repo rename) requires explicit user approval and consumer coordination regardless of execution mode.

Which approach?
