# Rapid Deploy Feedback Loop Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Shorten the first-deploy feedback loop for `gcp-dbt-terraform` from minutes-and-multiple-repos to seconds-and-this-repo, by adding plan-time composition tests, a consumer-side preflight script, and an in-module post-create probe.

**Architecture:** Three additions, each independently useful. (1) `examples/basic/` — a plannable root module with fake values that lets CI prove the module composes. (2) `tests/basic.tftest.hcl` — native `terraform test` running `command = plan` against the example, asserting on resource counts, names, and IAM principals. (3) `scripts/preflight.sh` — `gcloud` read-only checks consumers run before their first `terraform apply`. (4) Optional `null_resource` post-create probe in the module, gated behind `var.run_smoke_test = false`. No GCP credentials needed in CI; no apply happens until the consumer's apply.

**Tech Stack:** Terraform 1.6+, native `terraform test` framework, bash + `gcloud` CLI, GitHub Actions. No new dependencies.

---

## File Structure

**New files:**
- `examples/basic/main.tf` — minimal root module wiring this repo's root module with fake values
- `examples/basic/variables.tf` — empty (all values hardcoded for plannability)
- `examples/basic/versions.tf` — pins terraform + google provider, configures provider with a fake project
- `examples/basic/README.md` — explains this is a CI fixture, not a deploy target
- `tests/basic.tftest.hcl` — native test file, `command = plan`, ~5 assertions
- `scripts/preflight.sh` — consumer-side gcloud checks
- `docs/PREFLIGHT.md` — how/when consumers run preflight.sh

**Modified files:**
- `modules/dbt-runner/main.tf` — add optional `null_resource.smoke_probe` gated on `var.run_smoke_test`
- `modules/dbt-runner/variables.tf` — add `run_smoke_test` variable (default false)
- `main.tf` (root) — pass-through `run_smoke_test` (the four-file rule)
- `variables.tf` (root) — declare `run_smoke_test`
- `.github/workflows/pre-commit.yml` — add `terraform test` step after `terraform validate`
- `README.md` — link to `examples/basic/` and `docs/PREFLIGHT.md`

**Why this split:** `examples/basic/` and `tests/basic.tftest.hcl` are paired (the test runs against the example). `scripts/preflight.sh` lives separately because it's consumer-facing and doesn't share state with the test. The smoke probe is a single resource in the existing module file — no new file warranted.

---

## Task 1: Create the plannable example

**Files:**
- Create: `examples/basic/versions.tf`
- Create: `examples/basic/main.tf`
- Create: `examples/basic/variables.tf`
- Create: `examples/basic/README.md`

- [ ] **Step 1: Create `examples/basic/versions.tf`**

```hcl
# Pinned to match repo root. The fake provider config lets `terraform plan`
# run without GCP credentials — no API calls are made during plan.
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

- [ ] **Step 2: Create `examples/basic/variables.tf`**

```hcl
# Intentionally empty. All values are hardcoded in main.tf so the example
# is self-contained and `terraform plan` runs deterministically in CI.
```

- [ ] **Step 3: Create `examples/basic/main.tf`**

```hcl
# CI fixture: proves the root module composes against fake but well-formed
# inputs. Never deploy this — every value is a placeholder.

module "dbt_runner" {
  source = "../.."

  project_id  = "fake-project"
  environment = "ci"
  region      = "us-central1"
  repo_prefix = "rag-research"

  # VPC — fake but well-formed self-links
  network_id    = "projects/fake-project/global/networks/fake-vpc"
  subnetwork_id = "projects/fake-project/regions/us-central1/subnetworks/fake-subnet"

  # Postgres — fake values, full Secret Manager path format
  postgres_host            = "10.0.0.2"
  postgres_port            = 5432
  postgres_db              = "rag_taxonomy"
  postgres_user            = "rag_admin"
  postgres_password_secret = "projects/000000000000/secrets/fake-postgres-password/versions/latest"

  # Image — fake GCR URI
  dbt_image_uri = "gcr.io/fake-project/dbt:latest"

  # WIF — fake SA email
  wif_service_account = "github-actions@fake-project.iam.gserviceaccount.com"

  labels = {
    component  = "dbt"
    managed_by = "terraform"
    fixture    = "true"
  }
}
```

- [ ] **Step 4: Create `examples/basic/README.md`**

```markdown
# Basic example — CI fixture

This is **not** a deployable example. Every value is a placeholder. Its only
job is to let `terraform plan` and `terraform test` run in CI to prove the
root module composes correctly.

## Run locally

    cd examples/basic
    terraform init -backend=false
    terraform plan

A successful plan with ~7 resources to add means the module composition is
healthy. A failed plan means something in the root module wiring is broken.

## Why a fixture instead of a real example?

Real examples need real project IDs, real VPCs, real secrets. A fixture
needs none of that, runs without credentials, and catches the same class
of bugs (variable wiring, IAM principal types, secret_id format mismatches,
resource-name interpolations).
```

- [ ] **Step 5: Verify plan runs cleanly**

Run from repo root:
```powershell
cd examples/basic
terraform init -backend=false
terraform plan -no-color
cd ../..
```

Expected: plan succeeds, shows resources to add (Cloud Run Job, service account, IAM members). If `terraform plan` errors with "unknown variable" or "incorrect attribute type," fix the wiring in `main.tf` before continuing.

- [ ] **Step 6: Commit**

```bash
git add examples/basic/
git commit -m "feat: add plannable basic example as CI fixture"
```

---

## Task 2: Native `terraform test` for plan-time composition

**Files:**
- Create: `tests/basic.tftest.hcl`

- [ ] **Step 1: Write the failing test file**

```hcl
# Plan-time composition tests — no apply, no credentials needed.
# Runs against examples/basic/. Assertions check that the module wires up
# the resources we expect with the names and principals we expect.

run "basic_plan_composes" {
  command = plan

  module {
    source = "./examples/basic"
  }

  # The Cloud Run Job is named correctly
  assert {
    condition     = module.dbt_runner.job_name == "rag-research-ci-dbt"
    error_message = "job_name should be '${var.repo_prefix}-${var.environment}-dbt'"
  }

  # The job is in the expected region
  assert {
    condition     = module.dbt_runner.job_location == "us-central1"
    error_message = "job_location should equal var.region"
  }

  # Service account email is derived from prefix + environment
  assert {
    condition     = can(regex("^rag-research-ci-dbt-runner@", module.dbt_runner.service_account_email))
    error_message = "service_account_email should start with '${var.repo_prefix}-${var.environment}-dbt-runner@'"
  }

  # job_id parsing succeeds (the [5] split trick — see CLAUDE.md)
  assert {
    condition     = module.dbt_runner.job_id != ""
    error_message = "job_id parser returned empty — provider may have changed resource ID format"
  }
}
```

- [ ] **Step 2: Run the test, verify it executes**

Run from repo root:
```powershell
terraform init -backend=false
terraform test -verbose
```

Expected: `1 passed, 0 failed`. If you see `Error: Reference to undeclared output value`, an output is missing from `examples/basic/main.tf`'s `module "dbt_runner"` re-exports — but root `main.tf` already exposes `job_name`, `job_location`, `job_id`, `service_account_email`, so this should pass.

- [ ] **Step 3: Prove the test fails when something breaks (sanity check)**

Temporarily edit `tests/basic.tftest.hcl` line `condition = module.dbt_runner.job_name == "rag-research-ci-dbt"` to `== "wrong-name"`. Run `terraform test`. Expected: 1 failed. Revert the edit. Run again. Expected: 1 passed.

This confirms the test is actually exercising the assertion, not silently passing.

- [ ] **Step 4: Commit**

```bash
git add tests/basic.tftest.hcl
git commit -m "test: add plan-time composition tests via terraform test"
```

---

## Task 3: Wire `terraform test` into CI

**Files:**
- Modify: `.github/workflows/pre-commit.yml`

- [ ] **Step 1: Read current workflow**

Read `.github/workflows/pre-commit.yml` to see exact step ordering. The new test step goes **after** `Validate` and **before** `Run TFLint` so a composition failure surfaces before the lint step runs.

- [ ] **Step 2: Add the test step**

In `.github/workflows/pre-commit.yml`, after the step:

```yaml
      - name: Validate
        run: terraform validate
```

insert:

```yaml
      - name: Run terraform test
        run: terraform test -verbose
```

The existing `Initialize Terraform` step (`terraform init -backend=false`) already provides what `terraform test` needs.

- [ ] **Step 3: Verify YAML is valid**

Run from repo root (if `yamllint` is installed, otherwise skip):
```powershell
yamllint .github/workflows/pre-commit.yml
```

Expected: no errors. If yamllint complains about indentation, match the surrounding 6-space step indent exactly.

- [ ] **Step 4: Commit**

```bash
git add .github/workflows/pre-commit.yml
git commit -m "ci: run terraform test in pre-commit workflow"
```

---

## Task 4: Consumer preflight script — APIs and existence checks

**Files:**
- Create: `scripts/preflight.sh`

This is the highest-leverage piece. The script is consumer-run, so it lives in `scripts/` for the consumer to call as `bash gcp-dbt-terraform/scripts/preflight.sh`. We build it in two tasks: this one covers API enablement and resource existence; Task 5 covers the trickier IAM/region checks.

- [ ] **Step 1: Create script header and arg parsing**

Create `scripts/preflight.sh`:

```bash
#!/usr/bin/env bash
# =============================================================================
# preflight.sh — Consumer-side environment validation for gcp-dbt-terraform
# =============================================================================
# Run from the calling project before the first `terraform apply`. Performs
# read-only `gcloud` checks to surface IAM/API/region failures in seconds
# rather than minutes after a Cloud Run Job creation succeeds-but-cannot-run.
#
# Usage:
#   bash gcp-dbt-terraform/scripts/preflight.sh \
#     --project my-project \
#     --region us-central1 \
#     --secret projects/123/secrets/postgres-password/versions/latest \
#     --subnet projects/my-project/regions/us-central1/subnetworks/my-subnet \
#     --wif-sa github-actions@my-project.iam.gserviceaccount.com
#
# Exit codes:
#   0 = all checks passed, safe to apply
#   1 = arg parsing or gcloud missing
#   2 = required API not enabled
#   3 = referenced resource does not exist or wrong format
#   4 = IAM/region mismatch
# =============================================================================

set -euo pipefail

PROJECT=""
REGION=""
SECRET=""
SUBNET=""
WIF_SA=""

usage() {
  sed -n '2,20p' "$0"
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --project)  PROJECT="$2"; shift 2 ;;
    --region)   REGION="$2"; shift 2 ;;
    --secret)   SECRET="$2"; shift 2 ;;
    --subnet)   SUBNET="$2"; shift 2 ;;
    --wif-sa)   WIF_SA="$2"; shift 2 ;;
    -h|--help)  usage ;;
    *) echo "Unknown arg: $1"; usage ;;
  esac
done

for v in PROJECT REGION SECRET SUBNET WIF_SA; do
  if [[ -z "${!v}" ]]; then
    echo "Missing required arg: --${v,,}"
    usage
  fi
done

if ! command -v gcloud >/dev/null; then
  echo "gcloud CLI not found in PATH"
  exit 1
fi

echo "Preflight for project=$PROJECT region=$REGION"
echo ""
```

- [ ] **Step 2: Add API enablement check**

Append to `scripts/preflight.sh`:

```bash
# =============================================================================
# Check 1: Required APIs are enabled
# =============================================================================
echo "[1/5] Checking required APIs..."
REQUIRED_APIS=(run.googleapis.com secretmanager.googleapis.com compute.googleapis.com iam.googleapis.com)
ENABLED=$(gcloud services list --enabled --project="$PROJECT" --format="value(config.name)" 2>/dev/null)

MISSING=()
for api in "${REQUIRED_APIS[@]}"; do
  if ! grep -q "^$api$" <<<"$ENABLED"; then
    MISSING+=("$api")
  fi
done

if [[ ${#MISSING[@]} -gt 0 ]]; then
  echo "  FAIL: APIs not enabled in $PROJECT:"
  printf '    - %s\n' "${MISSING[@]}"
  echo "  Fix: gcloud services enable ${MISSING[*]} --project=$PROJECT"
  exit 2
fi
echo "  OK: all required APIs enabled"
echo ""
```

- [ ] **Step 3: Add secret-format and resolution check**

Append:

```bash
# =============================================================================
# Check 2: Secret reference format and resolution
# Module passes this raw to google_secret_manager_secret_iam_member.secret_id
# which expects either a short ID or a full path — the variable docs say
# full path, so we enforce that here.
# =============================================================================
echo "[2/5] Checking postgres password secret..."
if [[ ! "$SECRET" =~ ^projects/[^/]+/secrets/[^/]+(/versions/[^/]+)?$ ]]; then
  echo "  FAIL: --secret must be 'projects/X/secrets/Y' or 'projects/X/secrets/Y/versions/Z'"
  echo "  Got: $SECRET"
  exit 3
fi

# Strip /versions/X for the existence check
SECRET_BASE="${SECRET%/versions/*}"
if ! gcloud secrets describe "$SECRET_BASE" --project="$PROJECT" >/dev/null 2>&1; then
  echo "  FAIL: secret $SECRET_BASE does not exist or is not visible"
  exit 3
fi
echo "  OK: secret resolves"
echo ""
```

- [ ] **Step 4: Add subnet region-match check**

Append:

```bash
# =============================================================================
# Check 3: Subnet exists and lives in the same region as the Cloud Run Job
# A region mismatch only fails at apply time with a cryptic error.
# =============================================================================
echo "[3/5] Checking subnet..."
if [[ ! "$SUBNET" =~ ^projects/[^/]+/regions/([^/]+)/subnetworks/[^/]+$ ]]; then
  echo "  FAIL: --subnet must be a full self-link (projects/X/regions/Y/subnetworks/Z)"
  exit 3
fi
SUBNET_REGION="${BASH_REMATCH[1]}"

if [[ "$SUBNET_REGION" != "$REGION" ]]; then
  echo "  FAIL: subnet region '$SUBNET_REGION' != Cloud Run region '$REGION'"
  echo "  Cloud Run Job VPC access requires same-region subnetwork"
  exit 4
fi

if ! gcloud compute networks subnets describe \
    "$(basename "$SUBNET")" \
    --project="$PROJECT" \
    --region="$SUBNET_REGION" >/dev/null 2>&1; then
  echo "  FAIL: subnet $SUBNET does not exist"
  exit 3
fi
echo "  OK: subnet exists and matches region"
echo ""
```

- [ ] **Step 5: Add WIF service account existence check**

Append:

```bash
# =============================================================================
# Check 4: WIF service account exists
# =============================================================================
echo "[4/5] Checking WIF service account..."
if ! gcloud iam service-accounts describe "$WIF_SA" --project="$PROJECT" >/dev/null 2>&1; then
  echo "  FAIL: WIF service account $WIF_SA does not exist in $PROJECT"
  exit 3
fi
echo "  OK: WIF SA exists"
echo ""
```

- [ ] **Step 6: Add summary footer**

Append:

```bash
# =============================================================================
# Check 5: Summary
# =============================================================================
echo "[5/5] All preflight checks passed."
echo ""
echo "Safe to run: terraform apply"
```

- [ ] **Step 7: Make executable**

```bash
chmod +x scripts/preflight.sh
```

- [ ] **Step 8: Lint the script**

```powershell
# If shellcheck is installed locally; otherwise pre-commit will run it on push.
shellcheck scripts/preflight.sh
```

Expected: no warnings. If shellcheck flags `${!v}` (indirect expansion), suppress with `# shellcheck disable=SC1083` only if needed — bash 4+ supports it natively and `Dockerfile.dbt` already uses bash features.

- [ ] **Step 9: Smoke-test argument parsing locally**

```bash
bash scripts/preflight.sh --help
```
Expected: usage text from header. Then:
```bash
bash scripts/preflight.sh
```
Expected: `Missing required arg: --project` and exit 1.

- [ ] **Step 10: Commit**

```bash
git add scripts/preflight.sh
git commit -m "feat: add preflight.sh for consumer-side env validation"
```

---

## Task 5: Document preflight usage

**Files:**
- Create: `docs/PREFLIGHT.md`
- Modify: `README.md`

- [ ] **Step 1: Create `docs/PREFLIGHT.md`**

```markdown
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
```

- [ ] **Step 2: Add a Preflight section to root `README.md`**

Read `README.md`. After the `## Quick Start` block ends (currently line 55), insert:

```markdown
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
```

- [ ] **Step 3: Commit**

```bash
git add docs/PREFLIGHT.md README.md
git commit -m "docs: add preflight script documentation"
```

---

## Task 6: Optional in-module post-create probe

This task adds a `null_resource` that runs `gcloud run jobs describe` after Cloud Run Job creation, gated behind `var.run_smoke_test = false`. Default is off so existing consumers see no behavior change.

**Files:**
- Modify: `modules/dbt-runner/variables.tf`
- Modify: `modules/dbt-runner/main.tf`
- Modify: `variables.tf` (root)
- Modify: `main.tf` (root)

- [ ] **Step 1: Add `run_smoke_test` variable in nested module**

Append to `modules/dbt-runner/variables.tf` (under the existing Labeling section):

```hcl
# =============================================================================
# Smoke Test
# =============================================================================

variable "run_smoke_test" {
  description = "Run `gcloud run jobs describe` after creation to verify the job is queryable. Requires gcloud on the apply runner. Default false."
  type        = bool
  default     = false
}
```

- [ ] **Step 2: Add the probe resource**

Append to `modules/dbt-runner/main.tf`:

```hcl
# =============================================================================
# Smoke probe — verifies Cloud Run Job is queryable post-create
# Opt-in via var.run_smoke_test. Requires gcloud on the apply runner.
# =============================================================================

resource "null_resource" "smoke_probe" {
  count = var.run_smoke_test ? 1 : 0

  triggers = {
    job_id = google_cloud_run_v2_job.dbt.id
  }

  provisioner "local-exec" {
    command = "gcloud run jobs describe ${google_cloud_run_v2_job.dbt.name} --region=${google_cloud_run_v2_job.dbt.location} --project=${var.project_id} --format=value(name)"
  }
}
```

- [ ] **Step 3: Declare `null` provider requirement**

Read `modules/dbt-runner/` for an existing `versions.tf`. There is none — the module relies on the root's `versions.tf`. Add `null` to root `versions.tf`.

Modify `versions.tf` (root):

```hcl
terraform {
  required_version = ">= 1.6"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 7.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }
}

# Provider is configured by the consuming root module.
# This allows the module to be used with count, for_each, and depends_on.
```

- [ ] **Step 4: Apply the four-file rule — root `variables.tf`**

Append to `variables.tf` (root):

```hcl
# =============================================================================
# Smoke Test
# =============================================================================

variable "run_smoke_test" {
  description = "Run a post-create `gcloud run jobs describe` probe. Requires gcloud on the apply runner. Default false."
  type        = bool
  default     = false
}
```

- [ ] **Step 5: Apply the four-file rule — root `main.tf` pass-through**

In `main.tf` (root), inside the `module "dbt_runner"` block, after the `labels` line, add:

```hcl
  run_smoke_test = var.run_smoke_test
```

- [ ] **Step 6: Verify the example still plans and tests still pass**

Run from repo root:
```powershell
cd examples/basic
terraform init -backend=false -upgrade
terraform plan
cd ../..
terraform init -backend=false -upgrade
terraform test -verbose
```

Expected: plan succeeds (default `run_smoke_test = false` adds zero resources), tests pass.

- [ ] **Step 7: Add a test for the probe being conditional**

Edit `tests/basic.tftest.hcl`. After the existing `run "basic_plan_composes"` block, append:

```hcl
run "smoke_probe_off_by_default" {
  command = plan

  module {
    source = "./examples/basic"
  }

  # The example does not set run_smoke_test, so the null_resource count is 0
  assert {
    condition     = length([for r in run.basic_plan_composes.changes : r if can(regex("null_resource.smoke_probe", r))]) == 0
    error_message = "smoke_probe should not be planned when run_smoke_test is unset"
  }
}
```

If the assertion's `run.basic_plan_composes.changes` reference doesn't resolve in your terraform version, simplify to a plan-only existence check by adding to the existing `run "basic_plan_composes"` block instead:

```hcl
  # smoke probe is off by default
  assert {
    condition     = var.run_smoke_test == null || var.run_smoke_test == false
    error_message = "run_smoke_test should default to false in the example"
  }
```

Run `terraform test -verbose`. Expected: 1-2 passed.

- [ ] **Step 8: Commit**

```bash
git add modules/dbt-runner/variables.tf modules/dbt-runner/main.tf versions.tf variables.tf main.tf tests/basic.tftest.hcl
git commit -m "feat: add optional post-create smoke probe (run_smoke_test=false default)"
```

---

## Task 7: Update CLAUDE.md and final verification

**Files:**
- Modify: `CLAUDE.md`

- [ ] **Step 1: Add the new artifacts to CLAUDE.md**

In `CLAUDE.md`, find the `### Local validation (run before pushing)` block. Replace its `terraform validate` line with:

```powershell
terraform validate
terraform test -verbose                  # plan-time composition tests against examples/basic/
```

Then in the same file, find the line `## Conventions worth knowing` and just **before** it, insert:

```markdown
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
```

- [ ] **Step 2: Run the full local check suite end-to-end**

```powershell
terraform fmt -check -recursive
terraform init -backend=false -upgrade
terraform validate
terraform test -verbose
tflint --init --config=.tflint.hcl
tflint --config=.tflint.hcl
```

Expected: all green. If `terraform fmt -check` fails, run `terraform fmt -recursive` to fix.

- [ ] **Step 3: Final commit**

```bash
git add CLAUDE.md
git commit -m "docs: document feedback-loop tooling layers in CLAUDE.md"
```

---

## What this plan deliberately does not do

- **No Terratest, no Kitchen-Terraform, no real-apply integration tests.** Those need GCP credentials in CI, take 5+ minutes per run, and the failure modes they catch are mostly already covered by `preflight.sh` running with real credentials in the consumer's terminal. Revisit after first real deploy if a class of bug slipped through.
- **No checkov fix.** The `.pre-commit-config.yaml` checkov hook references `terraform/` which doesn't exist here. It's silently a no-op. Fixing it is a separate concern (checkov tuning is its own rabbit hole) and orthogonal to feedback-loop speed.
- **No `examples/with-postgres-module/`.** The README references it but it requires the `gcp-postgres-terraform` module to also exist. Add when that module's API stabilizes.
- **No live `dbt run` smoke test.** The optional probe is a `describe`, not an `execute`. Running `dbt --version` inside a job execution from Terraform is possible but couples module success to image presence and adds 30-60s to every apply. Defer until we see whether the basic probe is enough.

## Estimated effort

~4-6 hours for an engineer with this plan in hand. Tasks 1-3 are the highest-leverage and ship in the first ~2 hours.
