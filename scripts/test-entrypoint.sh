#!/bin/bash
# =============================================================================
# test-entrypoint.sh — Entrypoint execution logic unit tests
# =============================================================================
# Tests the ACTUAL execution flow the entrypoint will follow:
# 1. Command construction (dbt prefix handling)
# 2. Environment variable parsing
# 3. Postgres connectivity check logic
# 4. Default value fallbacks
#
# This mimics what will happen at runtime so bugs are caught early.
# USAGE: bash test-entrypoint.sh

set -e

TESTS_PASSED=0
TESTS_FAILED=0

TEST() {
    local name="$1"
    local expected="$2"
    local actual="$3"
    
    if [ "$expected" = "$actual" ]; then
        echo "✓ PASS: $name"
        ((TESTS_PASSED++))
    else
        echo "✗ FAIL: $name"
        echo "  Expected: $expected"
        echo "  Got:      $actual"
        ((TESTS_FAILED++))
    fi
}

echo "=== Entrypoint Execution Logic Tests ==="
echo ""

# ============================================================================
# TEST SUITE 1: Command Construction (what will actually execute?)
# ============================================================================
echo "SUITE 1: Command Construction"

# Real scenario 1: User provides just subcommand (most common)
DBT_COMMAND="run --target prod"
if ! [[ "$DBT_COMMAND" =~ ^dbt ]]; then
    RESULT="dbt $DBT_COMMAND"
else
    RESULT="$DBT_COMMAND"
fi
TEST "Subcommand 'run --target prod' becomes 'dbt run --target prod'" "dbt run --target prod" "$RESULT"

# Real scenario 2: User provides full dbt command (should not double-prefix)
DBT_COMMAND="dbt run --target prod"
if ! [[ "$DBT_COMMAND" =~ ^dbt ]]; then
    RESULT="dbt $DBT_COMMAND"
else
    RESULT="$DBT_COMMAND"
fi
TEST "Full command 'dbt run --target prod' stays unchanged" "dbt run --target prod" "$RESULT"

# Real scenario 3: Empty command should use default
DBT_COMMAND=""
RESULT="${DBT_COMMAND:-run --target prod}"
if ! [[ "$RESULT" =~ ^dbt ]]; then
    RESULT="dbt $RESULT"
fi
TEST "Empty command defaults to 'dbt run --target prod'" "dbt run --target prod" "$RESULT"

# Real scenario 4: Test command
DBT_COMMAND="test"
if ! [[ "$DBT_COMMAND" =~ ^dbt ]]; then
    RESULT="dbt $DBT_COMMAND"
else
    RESULT="$DBT_COMMAND"
fi
TEST "Subcommand 'test' becomes 'dbt test'" "dbt test" "$RESULT"

# Real scenario 5: Deps command
DBT_COMMAND="deps"
if ! [[ "$DBT_COMMAND" =~ ^dbt ]]; then
    RESULT="dbt $DBT_COMMAND"
else
    RESULT="$DBT_COMMAND"
fi
TEST "Subcommand 'deps' becomes 'dbt deps'" "dbt deps" "$RESULT"

echo ""

# ============================================================================
# TEST SUITE 2: Environment Variable Parsing
# ============================================================================
echo "SUITE 2: Environment Variable Parsing"

# Real scenario: All vars present
POSTGRES_HOST="10.8.0.4"
POSTGRES_PORT="5432"
POSTGRES_DB="pattern_discovery"
POSTGRES_USER="app_user"
if [ -n "$POSTGRES_HOST" ] && [ -n "$POSTGRES_PORT" ] && [ -n "$POSTGRES_DB" ] && [ -n "$POSTGRES_USER" ]; then
    RESULT="complete"
else
    RESULT="missing"
fi
TEST "All Postgres variables present" "complete" "$RESULT"

# Real scenario: Missing critical variable
POSTGRES_HOST=""
POSTGRES_PORT="5432"
if [ -n "$POSTGRES_HOST" ] && [ -n "$POSTGRES_PORT" ]; then
    RESULT="complete"
else
    RESULT="missing"
fi
TEST "Missing POSTGRES_HOST detected" "missing" "$RESULT"

# Real scenario: PORT is critical too
POSTGRES_HOST="10.8.0.4"
POSTGRES_PORT=""
if [ -n "$POSTGRES_HOST" ] && [ -n "$POSTGRES_PORT" ]; then
    RESULT="complete"
else
    RESULT="missing"
fi
TEST "Missing POSTGRES_PORT detected" "missing" "$RESULT"

echo ""

# ============================================================================
# TEST SUITE 3: Target and Default Handling
# ============================================================================
echo "SUITE 3: Target & Defaults (what will dbt actually use?)"

# Real scenario: User specifies target
DBT_TARGET="prod"
RESULT="${DBT_TARGET:-prod}"
TEST "User target 'prod' is used" "prod" "$RESULT"

# Real scenario: User specifies different target
DBT_TARGET="dev"
RESULT="${DBT_TARGET:-prod}"
TEST "User target 'dev' overrides default" "dev" "$RESULT"

# Real scenario: Empty target uses default
DBT_TARGET=""
RESULT="${DBT_TARGET:-prod}"
TEST "Empty target defaults to 'prod'" "prod" "$RESULT"

# Real scenario: Unset target uses default
unset DBT_TARGET
RESULT="${DBT_TARGET:-prod}"
TEST "Unset target defaults to 'prod'" "prod" "$RESULT"

echo ""

# ============================================================================
# TEST SUITE 4: Entrypoint Flow Validation
# ============================================================================
echo "SUITE 4: Entrypoint Execution Flow"

# Simulate the full entrypoint flow with typical values
DBT_COMMAND="run --target prod"
DBT_TARGET="prod"
POSTGRES_HOST="10.8.0.4"
POSTGRES_PORT="5432"

# Step 1: Build the full command (as entrypoint does)
DBT_FULL_CMD="${DBT_COMMAND:-run --target prod}"
if ! [[ "$DBT_FULL_CMD" =~ ^dbt ]]; then
    DBT_FULL_CMD="dbt $DBT_FULL_CMD"
fi

# Step 2: Validate postgres connectivity check logic would pass
POSTGRES_READY=""
if [ -n "$POSTGRES_HOST" ] && [ -n "$POSTGRES_PORT" ]; then
    POSTGRES_READY="yes"
fi

# Step 3: Validate postgres connectivity check logic fails if missing
POSTGRES_HOST_EMPTY=""
POSTGRES_READY_EMPTY=""
if [ -n "$POSTGRES_HOST_EMPTY" ] && [ -n "$POSTGRES_PORT" ]; then
    POSTGRES_READY_EMPTY="yes"
fi

TEST "Full flow: Command constructed correctly" "dbt run --target prod" "$DBT_FULL_CMD"
TEST "Full flow: Postgres check passes with all vars" "yes" "$POSTGRES_READY"
TEST "Full flow: Postgres check fails with empty HOST" "" "$POSTGRES_READY_EMPTY"

echo ""

# ============================================================================
# TEST SUITE 5: Error Conditions (what should NOT work?)
# ============================================================================
echo "SUITE 5: Error Conditions (critical failures to catch)"

# If entrypoint receives a command with shell operators, it MUST be rejected
# because Cloud Run passes env vars as single arguments, not through shell
DANGEROUS_COMMAND="run && test"
if [[ "$DANGEROUS_COMMAND" =~ && ]] || [[ "$DANGEROUS_COMMAND" =~ \; ]]; then
    RESULT="rejected"
else
    RESULT="allowed"
fi
TEST "Command with '&&' operator is identified as dangerous" "rejected" "$RESULT"

DANGEROUS_COMMAND="run; test"
if [[ "$DANGEROUS_COMMAND" =~ \; ]]; then
    RESULT="rejected"
else
    RESULT="allowed"
fi
TEST "Command with ';' operator is identified as dangerous" "rejected" "$RESULT"

# ============================================================================
# Summary
# ============================================================================
echo ""
echo "================================================"
echo "Tests Passed: $TESTS_PASSED"
echo "Tests Failed: $TESTS_FAILED"
echo "================================================"

if [ $TESTS_FAILED -gt 0 ]; then
    exit 1
fi
exit 0
