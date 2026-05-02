# Example: dbt Runner with failure notifications

Demonstrates wiring Cloud Run Job execution failures to a Pub/Sub topic via a
log-based sink. The Pub/Sub topic must already exist — the module grants the
sink's writer identity `roles/pubsub.publisher` on it.

Fixture-only. Values are placeholders.
