# dbt profiles.yml - PostgreSQL adapter configuration
# Schemas are dynamic based on dbt_schema_prefix variable (set via environment or CLI)
# Default: dbt_schema_prefix=${repo_prefix}
#
# This template should be copied into your project's dbt/ directory.
# Update ${repo_prefix} with your actual project prefix (e.g., "rag-research").

rag_taxonomy:
  target: prod
  outputs:
    dev:
      type: postgres
      host: "{{ env_var('POSTGRES_HOST', 'localhost') }}"
      port: 5432
      user: "{{ env_var('POSTGRES_USER', 'rag_admin') }}"
      password: "{{ env_var('POSTGRES_PASSWORD') }}"
      dbname: "{{ env_var('POSTGRES_DB', 'rag_taxonomy') }}"
      schema: "{{ env_var('REPO_PREFIX', '${repo_prefix}') }}_bronze"
      threads: 4
      keepalives_idle: 0
      connect_timeout: 10

    ci:
      type: postgres
      host: "{{ env_var('POSTGRES_HOST') }}"
      port: 5432
      user: "{{ env_var('POSTGRES_USER') }}"
      password: "{{ env_var('POSTGRES_PASSWORD') }}"
      dbname: "{{ env_var('POSTGRES_DB', 'rag_taxonomy') }}"
      schema: "{{ env_var('REPO_PREFIX', '${repo_prefix}') }}_bronze_ci"
      threads: 2
      keepalives_idle: 0
      connect_timeout: 30

    prod:
      type: postgres
      host: "{{ env_var('POSTGRES_HOST') }}"
      port: 5432
      user: "{{ env_var('POSTGRES_USER') }}"
      password: "{{ env_var('POSTGRES_PASSWORD') }}"
      dbname: "{{ env_var('POSTGRES_DB', 'rag_taxonomy') }}"
      schema: "{{ env_var('REPO_PREFIX', '${repo_prefix}') }}_bronze"
      threads: 2
      keepalives_idle: 30
      connect_timeout: 30
