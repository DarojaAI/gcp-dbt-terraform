# AGENTS.md

## Commands
- **Validate all**: `terraform fmt -check -recursive && terraform init -backend=false && terraform validate && tflint --config=.tflint.hcl`
- **Run single test**: `terraform test -verbose -filter=tests/basic.tftest.hcl` (or `cd examples/basic && terraform test -verbose`)
- **Pre-commit**: `pre-commit run --all-files`
- **Docker validation** (from consumer repo): `bash gcp-dbt-terraform/scripts/validate-dbt-docker.sh`
- **Preflight** (from consumer repo): `bash gcp-dbt-terraform/scripts/preflight.sh --project ...`

## Code Style
- **File headers**: Every `.tf` file opens with `# ===` banner naming its purpose. Use section banners (`# === Section Name ===`) to group variables/resources.
- **Four-file rule**: Adding a variable/output requires touching: root `variables.tf`, root `main.tf` (pass-through), `modules/dbt-runner/variables.tf`, `modules/dbt-runner/outputs.tf`. Root outputs are defined inline in `main.tf`, not in `outputs.tf`.
- **Naming**: Resources use `${var.repo_prefix}-${var.environment}-...`. Variables use `snake_case`. No provider block in module (consumer configures it).
- **Types**: Always declare `type` and `description` on variables. Use `validation` blocks for constraints. Defaults are RAG-flavored (`rag-research`, `rag_taxonomy`, `rag_admin`).
- **Secrets**: Never pass passwords as variable values — always use Secret Manager references via `value_source.secret_key_ref`.
- **No `.tfvars` in repo**: `.gitignore` excludes `*.tfvars` except `*.tfvars.example`.
- **Min versions**: Terraform `>= 1.6`, google provider `~> 7.0`.
- **CI runs without GCP creds** — keep it that way. Credential-requiring checks go in `scripts/preflight.sh`.
