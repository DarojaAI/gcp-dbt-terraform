# =============================================================================
# Plan-time composition tests — no apply, no credentials needed.
# Runs against examples/basic/. Assertions check that the module wires up
# the resources we expect with the names and principals we expect.
# =============================================================================

run "basic_plan_composes" {
  command = plan

  module {
    source = "./examples/basic"
  }

  # The Cloud Run Job is named correctly
  assert {
    condition     = module.dbt_runner.job_name == "rag-research-ci-dbt"
    error_message = "job_name should be rag-research-ci-dbt"
  }

  # The job is in the expected region
  assert {
    condition     = module.dbt_runner.job_location == "us-central1"
    error_message = "job_location should equal us-central1"
  }

  # Service account email is derived from prefix + environment
  assert {
    condition     = can(regex("^rag-research-ci-dbt-runner@", module.dbt_runner.service_account_email))
    error_message = "service_account_email should start with rag-research-ci-dbt-runner@"
  }
}

run "with_env_vars_plan" {
  command = plan

  module {
    source = "./examples/with-env-vars"
  }

  # Custom env vars must reach the container
  assert {
    condition = anytrue([
      for e in module.dbt_runner.container_env_names :
      e == "DBT_VARS"
    ])
    error_message = "DBT_VARS env var should be present on the dbt container"
  }

  assert {
    condition = anytrue([
      for e in module.dbt_runner.container_env_names :
      e == "ELEMENTARY_PROFILE"
    ])
    error_message = "ELEMENTARY_PROFILE env var should be present on the dbt container"
  }
}
