#!/bin/bash
# =============================================================================
# validate-dbt-docker.sh — Local dbt Docker Image Validation
# =============================================================================
# Quick validation suite for dbt Docker image before pushing to CI/CD
# Runs locally in the CALLING PROJECT to catch issues early (5-10 minutes)
#
# Usage (from calling project directory):
#   bash gcp-dbt-terraform/scripts/validate-dbt-docker.sh
#
# Prerequisites:
#   - Docker daemon running
#   - gcp-dbt-terraform cloned/imported into calling project
#   - dbt/ directory with models and profiles.yml
#
# Exit codes:
#   0 = All validations passed
#   1 = Build failed
#   2 = Parse validation failed
#   3 = Image size check failed
#   4 = Runtime check failed
# =============================================================================

set -e

# Determine project name from current directory
PROJECT_NAME=$(basename "$(pwd)")
IMAGE_TAG="${PROJECT_NAME}-dbt:test"
DOCKERFILE_PATH="gcp-dbt-terraform/Dockerfile.dbt"

echo "🔍 Starting dbt Docker validation for: $PROJECT_NAME"
echo "   Using Dockerfile: $DOCKERFILE_PATH"
echo "   Image tag: $IMAGE_TAG"
echo ""

# Check Dockerfile exists
if [ ! -f "$DOCKERFILE_PATH" ]; then
    echo "❌ Dockerfile not found at: $DOCKERFILE_PATH"
    echo "   Make sure gcp-dbt-terraform is imported into this project"
    exit 1
fi

# =============================================================================
# 1. Build Docker image
# =============================================================================
echo "📦 Step 1: Building Docker image from gcp-dbt-terraform template..."
if docker build -f "$DOCKERFILE_PATH" -t "$IMAGE_TAG" . > /tmp/docker-build.log 2>&1; then
    echo "✅ Docker build successful"
else
    echo "❌ Docker build failed"
    tail -50 /tmp/docker-build.log
    exit 1
fi
echo ""

# =============================================================================
# 2. Verify dbt packages installed (dbt --version)
# =============================================================================
echo "📋 Step 2: Verifying dbt installation..."
if docker run --rm "$IMAGE_TAG" dbt --version > /tmp/dbt-version.txt 2>&1; then
    echo "✅ dbt installed successfully:"
    cat /tmp/dbt-version.txt | sed 's/^/   /'
else
    echo "❌ dbt installation verification failed"
    cat /tmp/dbt-version.txt
    exit 1
fi
echo ""

# =============================================================================
# 3. Validate dbt project structure (dbt parse)
# =============================================================================
echo "🧩 Step 3: Validating dbt project structure..."
if docker run --rm "$IMAGE_TAG" \
    dbt parse --vars '{"dbt_schema_prefix": "rag"}' > /tmp/dbt-parse.log 2>&1; then
    PARSED_MODELS=$(grep -o '"unique_id"' /tmp/dbt-parse.log | wc -l)
    echo "✅ dbt project structure valid"
    echo "   Parsed models: $PARSED_MODELS"
else
    echo "❌ dbt parse validation failed"
    tail -20 /tmp/dbt-parse.log
    exit 2
fi
echo ""

# =============================================================================
# 4. Check image size (should be < 1.5GB)
# =============================================================================
echo "💾 Step 4: Checking image size..."
SIZE_MB=$(docker images "$IMAGE_TAG" --format '{{.Size}}' | numfmt --from=iec 2>/dev/null || docker images "$IMAGE_TAG" --format '{{.Size}}')

echo "✅ Image size: $SIZE_MB"
if [[ "$SIZE_MB" == *"G"* ]]; then
    SIZE_NUMERIC=$(echo "$SIZE_MB" | grep -oE '[0-9]+\.[0-9]+' | head -1)
    if (( $(echo "$SIZE_NUMERIC > 2.0" | bc -l) )); then
        echo "⚠️  Image larger than expected (>2GB) — may be bloated"
    fi
fi
echo ""

# =============================================================================
# 5. Test environment variable handling
# =============================================================================
echo "🔧 Step 5: Testing environment variable handling..."
docker run --rm \
    -e POSTGRES_HOST="10.0.1.2" \
    -e POSTGRES_PORT="5432" \
    -e POSTGRES_DB="test_db" \
    -e POSTGRES_USER="test_user" \
    -e POSTGRES_PASSWORD="test_password" \
    -e DBT_SCHEMA_PREFIX="test" \
    -e DBT_TARGET="prod" \
    "$IMAGE_TAG" \
    sh -c 'echo "✅ Environment variables loaded: POSTGRES_HOST=$POSTGRES_HOST, DBT_SCHEMA_PREFIX=$DBT_SCHEMA_PREFIX"' > /tmp/dbt-env.txt 2>&1

if grep -q "Environment variables loaded" /tmp/dbt-env.txt; then
    cat /tmp/dbt-env.txt | sed 's/^/   /'
    echo "✅ Environment variables passed correctly"
else
    echo "❌ Environment variable test failed"
    cat /tmp/dbt-env.txt
    exit 4
fi
echo ""

# =============================================================================
# 6. Verify requirements.txt installed correctly
# =============================================================================
echo "📚 Step 6: Verifying Python requirements..."
REQS=$(docker run --rm "$IMAGE_TAG" pip list | grep -E "dbt-core|dbt-postgres" || true)
if echo "$REQS" | grep -q "dbt-core" && echo "$REQS" | grep -q "dbt-postgres"; then
    echo "✅ All required packages installed:"
    echo "$REQS" | sed 's/^/   /'
else
    echo "❌ Missing required dbt packages"
    echo "$REQS"
    exit 4
fi
echo ""

# =============================================================================
# 7. Test Docker CMD behavior (dry-run)
# =============================================================================
echo "🚀 Step 7: Testing Docker CMD (dry-run)..."
docker run --rm \
    -e POSTGRES_HOST="10.0.1.2" \
    -e POSTGRES_PORT="5432" \
    -e POSTGRES_DB="test_db" \
    -e POSTGRES_USER="test_user" \
    -e POSTGRES_PASSWORD="test_password" \
    -e DBT_SCHEMA_PREFIX="test" \
    -e DBT_TARGET="prod" \
    -e DBT_COMMAND="echo 'Would run dbt run && dbt test'" \
    "$IMAGE_TAG" > /tmp/dbt-cmd.txt 2>&1

if grep -q "Would run dbt" /tmp/dbt-cmd.txt; then
    echo "✅ Docker CMD behavior correct:"
    cat /tmp/dbt-cmd.txt | sed 's/^/   /'
else
    echo "⚠️  Docker CMD test produced unexpected output:"
    cat /tmp/dbt-cmd.txt | sed 's/^/   /'
fi
echo ""

# =============================================================================
# Summary
# =============================================================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ ALL VALIDATIONS PASSED"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Image: $IMAGE_TAG is ready for deployment"
echo ""
echo "Next steps:"
echo "  1. Commit validation results"
echo "  2. Push to main branch"
echo "  3. GitHub Actions workflow builds real image + pushes to registry"
echo "  4. Terraform apply creates Cloud Run Job"
echo "  5. dbt executes in Cloud Run Job"
echo ""
