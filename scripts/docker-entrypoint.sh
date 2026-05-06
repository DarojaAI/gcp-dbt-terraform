#!/bin/bash
# =============================================================================
# docker-entrypoint.sh — Cloud Run Job entrypoint with diagnostics
# =============================================================================

set -e

LOG() { echo "[entrypoint] $(date -Iseconds) $*"; }

LOG "=== ENVIRONMENT DUMP ==="
env | sort

LOG "=== POSTGRES CONNECTIVITY CHECK ==="
if [ -n "$POSTGRES_HOST" ] && [ -n "$POSTGRES_PORT" ]; then
    timeout 10 bash -c "echo > /dev/tcp/$POSTGRES_HOST/$POSTGRES_PORT" 2>&1 \
        && LOG "TCP $POSTGRES_HOST:$POSTGRES_PORT → UP" \
        || LOG "TCP $POSTGRES_HOST:$POSTGRES_PORT → DOWN/timeout"
else
    LOG "POSTGRES_HOST/PORT not set — skipping TCP check"
fi

LOG "=== VALIDATING DBT INSTALLATION ==="
if ! command -v dbt &> /dev/null; then
    LOG "ERROR: dbt command not found in PATH"
    exit 127
fi
DBT_VERSION=$(dbt --version 2>&1 | head -1)
LOG "dbt version: $DBT_VERSION"

LOG "=== DBT DEBUG ==="
cd /app/dbt
if dbt debug --target "${DBT_TARGET:-prod}" 2>&1; then
    LOG "dbt debug: OK"
else
    LOG "WARNING: dbt debug returned non-zero (may still be recoverable)"
fi

LOG "=== EXECUTING COMMAND ==="
LOG "DBT_COMMAND=${DBT_COMMAND:-run --target prod}"
# Prepend 'dbt' to command if not already present
DBT_FULL_CMD="${DBT_COMMAND:-run --target prod}"
if ! [[ "$DBT_FULL_CMD" =~ ^dbt ]]; then
    DBT_FULL_CMD="dbt $DBT_FULL_CMD"
fi
LOG "Full command: $DBT_FULL_CMD"
exec sh -c "$DBT_FULL_CMD"