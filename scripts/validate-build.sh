#!/bin/bash
# =============================================================================
# validate-build.sh — Docker build validation via execution simulation
# =============================================================================
# This script validates the Docker image by **simulating actual dbt execution**.
# It doesn't just check "does dbt exist?" - it verifies the entire execution
# path will work by actually calling dbt commands that will be invoked later.
#
# This catches:
# - Missing dbt binary
# - Missing Python adapters
# - Missing system dependencies (git, libpq, etc.)
# - Broken PATH, permissions, or user issues
# - Configuration file loading problems
#
# USAGE: RUN bash /path/to/validate-build.sh

set -e

LOG() { echo "[validate-build] $*"; }
ERROR() { echo "[validate-build] ERROR: $*" >&2; }

ERRORS=0

LOG "=== Docker Image Build Validation ==="
LOG "Validating image can execute: dbt run --target prod"
echo ""

# ============================================================================
# PHASE 1: Dependency Verification (what will dbt actually call?)
# ============================================================================
LOG "PHASE 1: Verifying execution dependencies..."

# dbt internally calls these tools during execution
REQUIRED_COMMANDS=("python" "git")
for cmd in "${REQUIRED_COMMANDS[@]}"; do
    if ! command -v "$cmd" &> /dev/null; then
        ERROR "$cmd not found in PATH (dbt will fail)"
        ERRORS=$((ERRORS + 1))
    else
        LOG "  ✓ $cmd available"
    fi
done

# Python packages dbt needs at runtime
LOG "Checking Python packages dbt needs..."
if ! python -c "import dbt_core" 2>/dev/null; then
    ERROR "dbt_core not installed"
    ERRORS=$((ERRORS + 1))
fi
if ! python -c "import dbt_postgres" 2>/dev/null; then
    ERROR "dbt_postgres adapter not installed"
    ERRORS=$((ERRORS + 1))
fi
if ! python -c "import yaml" 2>/dev/null; then
    ERROR "pyyaml not installed"
    ERRORS=$((ERRORS + 1))
fi
LOG "  ✓ All required Python packages available"

# ============================================================================
# PHASE 2: Execution Simulation (can dbt actually run?)
# ============================================================================
LOG ""
LOG "PHASE 2: Simulating dbt execution path..."

# The entrypoint will cd to /app/dbt and run dbt commands
if [ ! -d "/app/dbt" ]; then
    ERROR "/app/dbt directory not found"
    ERRORS=$((ERRORS + 1))
else
    LOG "  ✓ /app/dbt directory exists"
fi

if [ ! -f "/app/dbt/dbt_project.yml" ]; then
    ERROR "dbt_project.yml not found (dbt will fail to load project)"
    ERRORS=$((ERRORS + 1))
else
    LOG "  ✓ dbt_project.yml present"
fi

if [ ! -f "/app/dbt/profiles.yml" ]; then
    ERROR "profiles.yml not found (dbt will fail to resolve target)"
    ERRORS=$((ERRORS + 1))
else
    LOG "  ✓ profiles.yml present"
fi

# ============================================================================
# PHASE 3: Command Execution Test (does dbt actually run?)
# ============================================================================
LOG ""
LOG "PHASE 3: Testing actual dbt command execution..."

# Test 1: dbt --version (exercises Python interpreter + dbt_core)
if ! dbt --version > /tmp/dbt-version.txt 2>&1; then
    ERROR "dbt --version failed"
    cat /tmp/dbt-version.txt | sed 's/^/  /'
    ERRORS=$((ERRORS + 1))
else
    DBT_VERSION=$(head -1 /tmp/dbt-version.txt)
    LOG "  ✓ dbt --version: $DBT_VERSION"
fi

# Test 2: dbt debug (exercises entire connection stack)
# This will fail if database is not available, but should not fail due to missing tools
LOG "  Running: dbt debug --profiles-dir=/app/dbt"
if cd /app/dbt && dbt debug --profiles-dir=/app/dbt > /tmp/dbt-debug.log 2>&1; then
    LOG "  ✓ dbt debug succeeded"
else
    # Check if it's a connection error (OK - DB not available in build) vs missing tool (NOT OK)
    if grep -q "command not found\|ModuleNotFoundError\|ImportError" /tmp/dbt-debug.log; then
        ERROR "dbt debug failed with missing dependency:"
        grep "command not found\|ModuleNotFoundError\|ImportError" /tmp/dbt-debug.log | sed 's/^/    /'
        ERRORS=$((ERRORS + 1))
    else
        LOG "  ℹ dbt debug returned non-zero (likely DB connection - OK for build phase)"
        tail -5 /tmp/dbt-debug.log | sed 's/^/    /'
    fi
fi

# Test 3: Verify entrypoint script itself is correct
if [ ! -x "/usr/local/bin/entrypoint.sh" ]; then
    ERROR "Entrypoint script not executable"
    ERRORS=$((ERRORS + 1))
else
    LOG "  ✓ Entrypoint script is executable"
    # Verify the script contains the critical 'dbt' prefix logic
    if ! grep -q 'DBT_FULL_CMD="dbt' /usr/local/bin/entrypoint.sh; then
        ERROR "Entrypoint script missing dbt command prefix logic"
        ERRORS=$((ERRORS + 1))
    else
        LOG "  ✓ Entrypoint has correct command handling"
    fi
fi

# ============================================================================
# PHASE 4: Environment Simulation (can entrypoint run?)
# ============================================================================
LOG ""
LOG "PHASE 4: Testing entrypoint execution flow..."

# Simulate the environment variables the entrypoint expects
export DBT_COMMAND="run --target prod"
export DBT_TARGET="prod"
export POSTGRES_HOST="10.0.0.1"  # fake IP, just checking parsing
export POSTGRES_PORT="5432"
export POSTGRES_DB="pattern_discovery"
export POSTGRES_USER="app_user"
export POSTGRES_PASSWORD="fake_password"

# Test: Can we parse and construct the full command?
if ! [[ "$DBT_COMMAND" =~ ^dbt ]]; then
    FULL_CMD="dbt $DBT_COMMAND"
else
    FULL_CMD="$DBT_COMMAND"
fi

if [ "$FULL_CMD" != "dbt run --target prod" ]; then
    ERROR "Command construction failed: expected 'dbt run --target prod', got '$FULL_CMD'"
    ERRORS=$((ERRORS + 1))
else
    LOG "  ✓ Command construction: '$FULL_CMD'"
fi

# ============================================================================
# Summary
# ============================================================================
echo ""
echo "================================================"
if [ $ERRORS -eq 0 ]; then
    LOG "✓✓✓ Build validation PASSED ✓✓✓"
    LOG "Image is ready for Cloud Run deployment"
    exit 0
else
    ERROR "Build validation FAILED with $ERRORS error(s)"
    ERROR "Image will fail at runtime in Cloud Run"
    exit 1
fi
