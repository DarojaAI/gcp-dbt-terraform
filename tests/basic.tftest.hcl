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

  # Defaults: max_retries = 0 (matches current hardcoded behavior)
  assert {
    condition     = module.dbt_runner.max_retries == 0
    error_message = "max_retries default must remain 0 (no behavior change)"
  }

  # Defaults: parallelism = 1
  assert {
    condition     = module.dbt_runner.parallelism == 1
    error_message = "parallelism default must remain 1 (no behavior change)"
  }
}

run "rejects_reserved_postgres_env_var" {
  command = plan

  # Test at the root module level so expect_failures can reference var.dbt_env_vars
  # (which now carries the same validation block as the nested module variable).
  variables {
    project_id               = "fake-project"
    environment              = "ci"
    network_id               = "projects/fake-project/global/networks/fake-vpc"
    subnetwork_id            = "projects/fake-project/regions/us-central1/subnetworks/fake-subnet"
    postgres_host            = "10.0.0.2"
    postgres_password_secret = "projects/000000000000/secrets/fake-postgres-password/versions/latest"
    dbt_image_uri            = "gcr.io/fake-project/dbt:latest"
    wif_service_account      = "github-actions@fake-project.iam.gserviceaccount.com"
    dbt_env_vars             = { POSTGRES_HOST = "10.0.0.99" }
  }

  expect_failures = [var.dbt_env_vars]
}

run "rejects_reserved_dbt_target_env_var" {
  command = plan

  variables {
    project_id               = "fake-project"
    environment              = "ci"
    network_id               = "projects/fake-project/global/networks/fake-vpc"
    subnetwork_id            = "projects/fake-project/regions/us-central1/subnetworks/fake-subnet"
    postgres_host            = "10.0.0.2"
    postgres_password_secret = "projects/000000000000/secrets/fake-postgres-password/versions/latest"
    dbt_image_uri            = "gcr.io/fake-project/dbt:latest"
    wif_service_account      = "github-actions@fake-project.iam.gserviceaccount.com"
    dbt_env_vars             = { DBT_TARGET = "dev" }
  }

  expect_failures = [var.dbt_env_vars]
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
