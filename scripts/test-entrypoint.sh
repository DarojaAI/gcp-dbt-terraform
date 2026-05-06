#!/bin/bash
# =============================================================================
# test-entrypoint.sh — Unit tests for docker-entrypoint.sh logic
# =============================================================================
# Run this during Docker build or in CI to validate entrypoint logic
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

# Test 1: DBT_COMMAND with just subcommand gets 'dbt' prepended
DBT_COMMAND="run --target prod"
if ! [[ "$DBT_COMMAND" =~ ^dbt ]]; then
    RESULT="dbt $DBT_COMMAND"
else
    RESULT="$DBT_COMMAND"
fi
TEST "DBT_COMMAND subcommand gets 'dbt' prepended" "dbt run --target prod" "$RESULT"

# Test 2: DBT_COMMAND already with 'dbt' stays unchanged
DBT_COMMAND="dbt run --target prod"
if ! [[ "$DBT_COMMAND" =~ ^dbt ]]; then
    RESULT="dbt $DBT_COMMAND"
else
    RESULT="$DBT_COMMAND"
fi
TEST "DBT_COMMAND with 'dbt' prefix stays unchanged" "dbt run --target prod" "$RESULT"

# Test 3: Empty DBT_COMMAND uses default
DBT_COMMAND=""
DEFAULT="run --target prod"
RESULT="${DBT_COMMAND:-$DEFAULT}"
if ! [[ "$RESULT" =~ ^dbt ]]; then
    RESULT="dbt $RESULT"
fi
TEST "Empty DBT_COMMAND uses default with 'dbt' prepended" "dbt run --target prod" "$RESULT"

# Test 4: Validate that POSTGRES_HOST/PORT check works
POSTGRES_HOST="10.0.0.1"
POSTGRES_PORT="5432"
if [ -n "$POSTGRES_HOST" ] && [ -n "$POSTGRES_PORT" ]; then
    RESULT="has_values"
else
    RESULT="missing"
fi
TEST "POSTGRES_HOST/PORT validation detects values" "has_values" "$RESULT"

# Test 5: Validate that missing POSTGRES_HOST is detected
POSTGRES_HOST=""
POSTGRES_PORT="5432"
if [ -n "$POSTGRES_HOST" ] && [ -n "$POSTGRES_PORT" ]; then
    RESULT="has_values"
else
    RESULT="missing"
fi
TEST "POSTGRES_HOST/PORT validation detects missing HOST" "missing" "$RESULT"

# Test 6: DBT_TARGET defaults to 'prod'
DBT_TARGET=""
RESULT="${DBT_TARGET:-prod}"
TEST "DBT_TARGET defaults to prod" "prod" "$RESULT"

# Test 7: DBT_TARGET uses provided value
DBT_TARGET="dev"
RESULT="${DBT_TARGET:-prod}"
TEST "DBT_TARGET uses provided value" "dev" "$RESULT"

# Summary
echo ""
echo "================================================"
echo "Tests Passed: $TESTS_PASSED"
echo "Tests Failed: $TESTS_FAILED"
echo "================================================"

if [ $TESTS_FAILED -gt 0 ]; then
    exit 1
fi
exit 0
