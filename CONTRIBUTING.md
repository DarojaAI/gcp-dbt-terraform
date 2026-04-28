# Contributing to gcp-dbt-terraform

See [DarojaAI/.github/CONTRIBUTING.md](https://github.com/DarojaAI/.github/blob/main/CONTRIBUTING.md) for organization-wide guidelines.

## This Repo: DBT + Terraform on Google Cloud

This repository manages DBT (data build tool) infrastructure on Google Cloud Platform using Terraform.

### Setup

```bash
# Install Terraform
terraform version  # Should be ≥1.5.0

# Install DBT & dependencies
pip install -r requirements-dev.txt

# Install pre-commit hooks
pre-commit install
```

### Development Workflow

```bash
# Format & validate
terraform fmt -recursive terraform/
terraform -chdir=terraform validate

# DBT development (if applicable)
dbt debug
dbt run --select [model]

# Pre-commit check before commit
pre-commit run --all-files
```

### PR Requirements

1. **Terraform changes:**
   - Must include `terraform plan` output
   - Review Checkov security warnings
   - Test in dev environment

2. **DBT changes:**
   - Updated dbt_project.yml
   - Test all models: `dbt run`
   - Check docs: `dbt docs generate`

3. **All changes:**
   - Pre-commit passing
   - CHANGELOG updated (if applicable)

### Versioning

Version in `package.json`. GitHub Actions auto-tags on version bump.

```bash
npm version patch  # or minor/major
```

---

For questions, see [GOVERNANCE.md](https://github.com/DarojaAI/.github/blob/main/GOVERNANCE.md)
