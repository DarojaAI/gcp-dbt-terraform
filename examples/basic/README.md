# Basic example — CI fixture

This is **not** a deployable example. Every value is a placeholder. Its only
job is to let `terraform plan` and `terraform test` run in CI to prove the
root module composes correctly.

## Run locally

    cd examples/basic
    terraform init -backend=false
    terraform plan

A successful plan with ~7 resources to add means the module composition is
healthy. A failed plan means something in the root module wiring is broken.

## Why a fixture instead of a real example?

Real examples need real project IDs, real VPCs, real secrets. A fixture
needs none of that, runs without credentials, and catches the same class
of bugs (variable wiring, IAM principal types, secret_id format mismatches,
resource-name interpolations).