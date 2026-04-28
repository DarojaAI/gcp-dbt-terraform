# dbt Docker Image Validation Guide

> **For projects using gcp-dbt-terraform**: This guide provides local validation steps before deploying dbt transformations on Cloud Run.

## Quick Validation (5–10 minutes)

### Prerequisites
- Docker daemon running
- Working directory: Your project repository root (the one that imports gcp-dbt-terraform)
- dbt/ directory with models and configuration

### Step 1: Build the Docker Image
```bash
# Use Dockerfile from gcp-dbt-terraform, build context from your project
docker build -f gcp-dbt-terraform/Dockerfile.dbt -t your-project-dbt:test .
```

**Expected output:**
- No errors in build steps
- Successfully tagged `your-project-dbt:test`
- dbt-core and dbt-postgres installed in output

### Step 2: Verify dbt Installation
```bash
docker run --rm your-project-dbt:test dbt --version
```

**Expected output:**
```
core:
  installed version: 1.8.x
  version_database schema: x.x
postgres adapter:
  installed version: 1.8.x
```

If you see **"dbt: command not found"** → dbt packages are missing; check gcp-dbt-terraform/Dockerfile.dbt and dbt/requirements.txt.

### Step 3: Validate dbt Project Structure
```bash
docker run --rm your-project-dbt:test \
  dbt parse --vars '{"dbt_schema_prefix": "your_prefix"}'
```

**Expected output:**
- No errors
- Output contains JSON with parsed model definitions
- Message about successfully parsed nodes

**Indicates:**
- ✅ dbt_project.yml is valid
- ✅ YAML parsing works correctly
- ✅ All models (.sql files) are syntactically valid
- ✅ Profiles.yml can be read

### Step 4: Check Image Size
```bash
docker images your-project-dbt:test
```

**Expected output:**
```
REPOSITORY              TAG    IMAGE ID    SIZE
your-project-dbt        test   abc123...   ~650MB-800MB
```

- Should be <1GB typically (if >1.5GB, may have unnecessary files)

### Step 5: Test Environment Variable Handling
```bash
docker run --rm \
  -e POSTGRES_HOST="10.0.1.2" \
  -e POSTGRES_PORT="5432" \
  -e POSTGRES_DB="your_database" \
  -e POSTGRES_USER="your_user" \
  -e POSTGRES_PASSWORD="test_password" \
  -e DBT_SCHEMA_PREFIX="your_prefix" \
  -e DBT_TARGET="prod" \
  -e DBT_COMMAND="echo 'Would run: dbt run && dbt test'" \
  your-project-dbt:test
```

**Expected output:**
```
Would run: dbt run && dbt test
```

Confirms:
- ✅ Environment variables passed correctly
- ✅ Docker ENTRYPOINT and CMD work as expected
- ✅ Shell variable expansion works

### Step 6: Verify Python Packages
```bash
docker run --rm your-project-dbt:test pip list | grep -E "dbt-core|dbt-postgres"
```

**Expected output:**
```
dbt-core        1.8.x
dbt-postgres    1.8.x
```

If missing → Dockerfile.dbt installation step failed.

## Automated Validation Script

Run all 7 validations at once:
```bash
bash gcp-dbt-terraform/scripts/validate-dbt-docker.sh
```

This runs sequentially:
1. Build Docker image
2. Verify dbt installation
3. Validate project structure (dbt parse)
4. Check image size
5. Test environment variables
6. Verify Python requirements
7. Test Docker CMD behavior (dry-run)

**Exit codes:**
- `0` = All validations passed ✅ Safe to deploy
- `1` = Docker build failed
- `2` = dbt parse validation failed (project structure issue)
- `3` = Image size check failed
- `4` = Runtime validation failed

## What Each Validation Catches

| Check | Validates | Catches |
|-------|-----------|---------|
| Docker build | Dockerfile syntax | Missing COPY files, syntax errors |
| dbt --version | Package installation | dbt not installed (exit 127 prevention) |
| dbt parse | Project structure | Invalid YAML, syntax errors, missing models |
| Image size | Bloat detection | Unnecessary dependencies, large files |
| Environment vars | Shell integration | Variable passing, escaping issues |
| Python packages | Requirements.txt | Missing dbt or other dependencies |
| Docker CMD | Entrypoint/CMD | Variable expansion, command execution |

## Deployment Flow (After Validation)

Once local validation passes:

1. **Commit your dbt changes** to your project repo
2. **Push to main branch**
3. **GitHub Actions workflow auto-triggers** (monitors dbt/**, Dockerfile*, etc.)
4. **Docker build** happens in CI/CD (uses gcp-dbt-terraform/Dockerfile.dbt + your context)
5. **Image tagged** as `:latest` and pushed to container registry
6. **Wait for replication** (registry propagation, ~10 seconds)
7. **Terraform apply** (via gcp-dbt-terraform module) creates Cloud Run Job
8. **Cloud Run Job executes** dbt run + dbt test
9. **Results** logged to Cloud Logging

## Root Cause: Why dbt Exit Code 127?

```
Error: dbt: command not found (exit 127)
```

**Root cause:** dbt packages (dbt-core, dbt-postgres) were not installed in the Docker image.

**How it happens:**
1. Dockerfile has `COPY dbt/ ./dbt/` (brings in project dbt files)
2. But dbt binaries themselves weren't installed via pip
3. Cloud Run Job starts container
4. Executes: `dbt run` → shell can't find dbt → exit 127

**Why gcp-dbt-terraform solves this:**
- Dockerfile.dbt includes: `pip install dbt-core>=1.8.0 dbt-postgres>=1.8.0`
- dbt/requirements.txt has the exact versions
- Every project using gcp-dbt-terraform gets this automatically
- No project has to re-solve this problem

## Troubleshooting

### Issue: "dbt: command not found" (exit 127)
**Diagnosis:**
```bash
docker run --rm your-project-dbt:test which dbt
```
Should output `/usr/local/bin/dbt` (not "not found")

**Fix:**
- Ensure gcp-dbt-terraform/Dockerfile.dbt has the pip install line
- Check dbt/requirements.txt exists in your project
- Try building with `--no-cache`: `docker build --no-cache -f gcp-dbt-terraform/Dockerfile.dbt .`

### Issue: "dbt parse" fails with YAML error
**Diagnosis:**
```bash
docker run --rm your-project-dbt:test dbt parse 2>&1 | grep -A5 "ERROR"
```

**Common causes:**
- Invalid YAML in dbt/models/**/*.yml
- Incorrect variable syntax (should be Jinja: `{{ var('name') }}`)
- Profile not finding dbt_project.yml

**Fix:**
- Validate YAML: `yamllint dbt/models/**/*.yml`
- Check dbt_project.yml location and name
- Verify profiles.yml references correct profile name

### Issue: Environment variables not passed
**Diagnosis:**
```bash
docker run --rm your-project-dbt:test \
  env | grep POSTGRES
```
Should show POSTGRES_* variables you passed with -e

**Common causes:**
- Profiles.yml not using `{{ env_var() }}` syntax
- Typos in variable names (case-sensitive)
- dbt parsing before env vars are loaded

**Fix:**
- Use correct template syntax: `"{{ env_var('POSTGRES_HOST', 'localhost') }}"`
- Test with: `docker run --rm -e VAR=test your-project-dbt:test env | grep VAR`

### Issue: Image too large (>1.5GB)
**Diagnosis:**
```bash
docker images your-project-dbt:test
docker run --rm your-project-dbt:test du -sh /app /usr/local /var
```

**Common causes:**
- Large test data in dbt/data/
- Git history included in COPY
- Python package caches not cleaned
- Multiple copies of dependencies

**Fix:**
- Add `.dockerignore`: exclude test data, .git, __pycache__, .pyc
- Use `--no-cache-dir` in pip install (already in gcp-dbt-terraform)
- Remove unnecessary COPY steps

## Integration with gcp-dbt-terraform

When using gcp-dbt-terraform:

1. **gcp-dbt-terraform provides:**
   - Dockerfile.dbt (template)
   - dbt/requirements.txt (standard packages)
   - scripts/validate-dbt-docker.sh (validation suite)
   - Terraform module for Cloud Run Job

2. **Your project provides:**
   - dbt/models/ (your transformations)
   - dbt/profiles.yml (database config)
   - dbt_project.yml (project settings)
   - GitHub Actions workflow (orchestration)

3. **Result:**
   - One Docker image with template + your content
   - Consistent deployment across projects
   - Local validation catches issues before CI/CD

## Next Steps

✅ **Before committing:**
1. Run: `bash gcp-dbt-terraform/scripts/validate-dbt-docker.sh`
2. All 7 checks should pass (exit code 0)
3. Note any warnings (⚠️ items) for optimization

✅ **After push to main:**
1. GitHub Actions auto-triggers
2. Monitor workflow run (Docker build)
3. Check Cloud Run Job execution in GCP Console
4. View dbt logs in Cloud Logging
5. Verify data in PostgreSQL database

## References

- **gcp-dbt-terraform**: https://github.com/DarojaAI/gcp-dbt-terraform
- **dbt Documentation**: https://docs.getdbt.com/
- **dbt Postgres Adapter**: https://docs.getdbt.com/reference/warehouse-setups/postgres-setup
- **dbt Docker Best Practices**: https://docs.getdbt.com/guides/orchestration/docker/
- **Cloud Run Jobs**: https://cloud.google.com/run/docs/quickstarts/jobs/create-execute
- **Terraform Modules**: https://www.terraform.io/language/modules/develop
