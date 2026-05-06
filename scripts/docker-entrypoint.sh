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

LOG "=== DBT DEBUG ==="
cd /app/dbt
dbt debug --target "${DBT_TARGET:-prod}" 2>&1 || LOG "dbt debug returned non-zero"

LOG "=== EXECUTING COMMAND ==="
LOG "DBT_COMMAND=${DBT_COMMAND:-dbt run --target prod}"
exec sh -c "${DBT_COMMAND:-dbt run --target prod}"