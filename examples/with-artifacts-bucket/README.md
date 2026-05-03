# Example: dbt Runner with artifacts bucket

Demonstrates the optional GCS bucket for `target/manifest.json` and
`target/catalog.json`. The dbt container must `gsutil cp` to
`gs://$DBT_ARTIFACTS_BUCKET/` after each run — this module only provisions
the bucket and grants the runner service account `storage.objectAdmin`.

Fixture-only. Values are placeholders.
