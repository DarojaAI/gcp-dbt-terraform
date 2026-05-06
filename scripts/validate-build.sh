#!/bin/bash
# =============================================================================
# validate-build.sh — Docker build validation checks
# =============================================================================
# Run this in the final Docker image to validate:
# - dbt command is installed and callable
# - Python environment is correct
# - Essential packages are present
# - Entrypoint script is executable
#
# USAGE: RUN bash /path/to/validate-build.sh

set -e

LOG() { echo "[validate-build] $*"; }

ERRORS=0

# Check 1: dbt command exists
LOG "Check 1: dbt command exists..."
if ! command -v dbt &> /dev/null; then
    LOG "ERROR: dbt command not found in PATH"
    ERRORS=$((ERRORS + 1))
else
    LOG "✓ dbt found at: $(which dbt)"
fi

# Check 2: dbt version
LOG "Check 2: dbt version..."
if dbt --version > /dev/null 2>&1; then
    DBT_VERSION=$(dbt --version 2>&1 | head -1)
    LOG "✓ dbt version: $DBT_VERSION"
else
    LOG "ERROR: dbt --version failed"
    ERRORS=$((ERRORS + 1))
fi

# Check 3: dbt-postgres adapter installed
LOG "Check 3: dbt-postgres adapter..."
if python -c "import dbt_postgres" 2>/dev/null; then
    LOG "✓ dbt-postgres adapter found"
else
    LOG "ERROR: dbt-postgres adapter not installed"
    ERRORS=$((ERRORS + 1))
fi

# Check 4: Python version
LOG "Check 4: Python version..."
PYTHON_VERSION=$(python --version 2>&1)
LOG "✓ $PYTHON_VERSION"

# Check 5: PostgreSQL client tools
LOG "Check 5: psql client..."
if command -v psql &> /dev/null; then
    LOG "✓ psql found"
else
    LOG "WARNING: psql not found (may not be needed if using dbt adapter)"
fi

# Check 6: git command
LOG "Check 6: git command..."
if command -v git &> /dev/null; then
    LOG "✓ git found"
else
    LOG "ERROR: git not found (required for dbt)"
    ERRORS=$((ERRORS + 1))
fi

# Check 7: Entrypoint script exists and is executable
LOG "Check 7: Entrypoint script..."
if [ -x "/usr/local/bin/entrypoint.sh" ]; then
    LOG "✓ Entrypoint script is executable"
else
    LOG "ERROR: Entrypoint script not executable"
    ERRORS=$((ERRORS + 1))
fi

# Check 8: dbt project files exist
LOG "Check 8: dbt project files..."
if [ -f "/app/dbt/dbt_project.yml" ]; then
    LOG "✓ dbt_project.yml exists"
else
    LOG "ERROR: dbt_project.yml not found"
    ERRORS=$((ERRORS + 1))
fi

if [ -f "/app/dbt/profiles.yml" ]; then
    LOG "✓ profiles.yml exists"
else
    LOG "ERROR: profiles.yml not found"
    ERRORS=$((ERRORS + 1))
fi

# Check 9: Working directory is correct
LOG "Check 9: Working directory..."
if [ "$(pwd)" = "/app/dbt" ]; then
    LOG "✓ Working directory is /app/dbt"
else
    LOG "WARNING: Working directory is $(pwd), expected /app/dbt"
fi

# Check 10: Current user is dbtuser (non-root)
LOG "Check 10: User privilege..."
CURRENT_USER=$(whoami)
if [ "$CURRENT_USER" = "dbtuser" ]; then
    LOG "✓ Running as non-root user: $CURRENT_USER"
elif [ "$CURRENT_USER" = "root" ]; then
    LOG "WARNING: Running as root (security issue)"
else
    LOG "✓ Running as user: $CURRENT_USER"
fi

# Summary
echo ""
echo "================================================"
if [ $ERRORS -eq 0 ]; then
    LOG "✓ All validation checks passed!"
    exit 0
else
    LOG "✗ $ERRORS validation check(s) failed"
    exit 1
fi
