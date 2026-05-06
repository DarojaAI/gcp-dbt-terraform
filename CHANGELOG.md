# Changelog

## [3.0.0](https://github.com/DarojaAI/gcp-dbt-terraform/compare/v2.1.0...v3.0.0) (2026-05-06)


### ⚠ BREAKING CHANGES

* Consumers must now set var.postgres_db and var.postgres_user explicitly. The rag_research_tool consumer (the original source of these defaults) already sets both via module.postgres outputs, so its deploy is unaffected.

### Features

* remove project-specific defaults for postgres_db and postgres_user ([#24](https://github.com/DarojaAI/gcp-dbt-terraform/issues/24)) ([13c2d26](https://github.com/DarojaAI/gcp-dbt-terraform/commit/13c2d26edf7c2c1a8d94f02d1f3adfc0a84eedcf))


### Bug Fixes

* add dbt deps to Dockerfile to install packages from packages.yml ([#18](https://github.com/DarojaAI/gcp-dbt-terraform/issues/18)) ([a8b7497](https://github.com/DarojaAI/gcp-dbt-terraform/commit/a8b7497a5555cd1aff730e00f310a34a581bc1fd))
* **ci:** discover terraform tests from repo root ([#21](https://github.com/DarojaAI/gcp-dbt-terraform/issues/21)) ([45ac939](https://github.com/DarojaAI/gcp-dbt-terraform/commit/45ac9398846c8a748247876075cfc2ec81332ace))

## [2.1.0](https://github.com/DarojaAI/gcp-dbt-terraform/compare/v2.0.1...v2.1.0) (2026-05-05)


### Features

* add dbt profiles.yml template with optimized connection pooling defaults ([#15](https://github.com/DarojaAI/gcp-dbt-terraform/issues/15)) ([7c4f29e](https://github.com/DarojaAI/gcp-dbt-terraform/commit/7c4f29e465ba638a66ff9559725b1ad8a68e60c5))

## [2.0.1](https://github.com/DarojaAI/gcp-dbt-terraform/compare/v2.0.0...v2.0.1) (2026-05-03)


### Bug Fixes

* expose deletion_protection variable to allow terraform-managed destroy ([#12](https://github.com/DarojaAI/gcp-dbt-terraform/issues/12)) ([4be8cf6](https://github.com/DarojaAI/gcp-dbt-terraform/commit/4be8cf69bce267fe058573d56b49ea3b1ac5a4e3))

## [2.0.0](https://github.com/DarojaAI/gcp-dbt-terraform/compare/v1.1.0...v2.0.0) (2026-05-03)


### ⚠ BREAKING CHANGES

* Consumers passing dbt_schema_prefix as a Terraform input must remove it. The dbt schema prefix is now derived from REPO_PREFIX in dbt_project.yml.

### Features

* add 4 module features + prep for Terraform Registry publication ([#11](https://github.com/DarojaAI/gcp-dbt-terraform/issues/11)) ([04a3fda](https://github.com/DarojaAI/gcp-dbt-terraform/commit/04a3fdad46f6c53003190ce54c93079091710316))
* add dbt Docker image template and validation suite ([d2418ca](https://github.com/DarojaAI/gcp-dbt-terraform/commit/d2418ca4a90c595b73052520f2ed10465670f5c2))
* add plannable basic example as CI fixture ([f7c3a14](https://github.com/DarojaAI/gcp-dbt-terraform/commit/f7c3a14e918b48ee355d872b4e3bfc7464386e04))
* add smoke probe, preflight docs, and CLAUDE.md updates ([3f32d54](https://github.com/DarojaAI/gcp-dbt-terraform/commit/3f32d5490f8013282afcb6b83668d9cf9be7eac6))
* add terraform test and preflight script ([2dc2a4b](https://github.com/DarojaAI/gcp-dbt-terraform/commit/2dc2a4b1896e1676985a2a9eea5e32d30fc9ff4f))
* add tflint validation to catch provider schema issues ([0339e67](https://github.com/DarojaAI/gcp-dbt-terraform/commit/0339e670818beff0dd4932a53de0c9b048b717d7))
* add variable descriptions and integrate checkov security scanning ([fbe02be](https://github.com/DarojaAI/gcp-dbt-terraform/commit/fbe02be7a23e586e2bc8a3801f80bac66fe5c1b8))
* Add version tracking (1.0.0) and standardize to google provider 7.0 ([373baac](https://github.com/DarojaAI/gcp-dbt-terraform/commit/373baac0d9d3217d44564103153cd8b281f64170))
* initial terraform module for Cloud Run Job-based dbt execution ([2f4e509](https://github.com/DarojaAI/gcp-dbt-terraform/commit/2f4e5092f68f996d9af680c900bb0b9792535fff))


### Bug Fixes

* adopt Terraform standard module structure ([56e45e1](https://github.com/DarojaAI/gcp-dbt-terraform/commit/56e45e1aaf8a9eddb87733f36a8fd79ed4b70017))
* correct Cloud Run Job v2 resource schema (nested template) ([36af737](https://github.com/DarojaAI/gcp-dbt-terraform/commit/36af7374fa2d8aa62040f989d43429bea4350386))
* correct output names to match nested module outputs ([a30a05c](https://github.com/DarojaAI/gcp-dbt-terraform/commit/a30a05c5bd2773d7946ffb2a8cb02b49840ac401))
* correct VPC access and IAM role for Cloud Run Job ([8678b69](https://github.com/DarojaAI/gcp-dbt-terraform/commit/8678b6907048a37df6274110a46e5af1d69cb56d))
* derive job_id from job_full_name ([90ed47c](https://github.com/DarojaAI/gcp-dbt-terraform/commit/90ed47c702aa63b7879417bbc257aed35ce6faa9))
* disable terraform_unused_declarations rule ([d8d664c](https://github.com/DarojaAI/gcp-dbt-terraform/commit/d8d664cbd27b04d40eb27db60af87f65f375daa5))
* init examples/basic in CI to avoid null provider error ([5003740](https://github.com/DarojaAI/gcp-dbt-terraform/commit/50037407a7e9396d7ac8ee2988b6df554e07fd11))
* place vpc_access at correct nesting level with network_interfaces ([19f9b05](https://github.com/DarojaAI/gcp-dbt-terraform/commit/19f9b05e711b790daf2d7d425aad8868ca957eb8))
* place vpc_access inside inner template block ([618ca1b](https://github.com/DarojaAI/gcp-dbt-terraform/commit/618ca1b1fd57792e40c1492dc11a33a669dd3299))
* remove dbt parse from build step (requires database at runtime) ([5ca5d17](https://github.com/DarojaAI/gcp-dbt-terraform/commit/5ca5d17e796d050603bd83cfe0b4992320850254))
* remove duplicate outputs.tf (use main.tf instead) ([da95b90](https://github.com/DarojaAI/gcp-dbt-terraform/commit/da95b90e18c01d88f81f1385c9e98a309210ed34))
* remove non-existent vpc_connector_id output ([cb36b92](https://github.com/DarojaAI/gcp-dbt-terraform/commit/cb36b92af2079a22272a14ebcd4c458303e6c705))
* remove nonexistent depends_on and use correct IAM binding resource ([5690ed8](https://github.com/DarojaAI/gcp-dbt-terraform/commit/5690ed8c28a47273fb9d6bb240082345b9b08695))
* remove provider block from module to support count/for_each ([881fbc6](https://github.com/DarojaAI/gcp-dbt-terraform/commit/881fbc6ea9249d605d91a4ca2dbcb8452edabe6a))
* run terraform test from examples/basic directory ([fec409f](https://github.com/DarojaAI/gcp-dbt-terraform/commit/fec409f4ab3bb9b1fef6cc956d0c38898d3156ff))
* single-line pip install to avoid shell redirect issues with version constraints ([6be1011](https://github.com/DarojaAI/gcp-dbt-terraform/commit/6be1011bd11e9d3fed0b5b75c948d53611ee7caf))
* use correct tflint_version parameter ([454cfea](https://github.com/DarojaAI/gcp-dbt-terraform/commit/454cfea71a9d224b125f7abdcd24d3e7bd3354a7))
* use exec form for RUN pip install to avoid shell metacharacter parsing ([1140e30](https://github.com/DarojaAI/gcp-dbt-terraform/commit/1140e3066344569aead7ca0e7cae762cd7dac8f2))
* use google_compute_subnetwork_iam_member for VPC access ([1c12101](https://github.com/DarojaAI/gcp-dbt-terraform/commit/1c12101f7511ce861859681035b2abc673722b6a))
* use REPO_PREFIX env var instead of DBT_SCHEMA_PREFIX ([#9](https://github.com/DarojaAI/gcp-dbt-terraform/issues/9)) ([b9e8fcd](https://github.com/DarojaAI/gcp-dbt-terraform/commit/b9e8fcd12094a2fc29a8a707a76271fe48b1dc23))
* wire job_* variables to nested module ([1ce99b8](https://github.com/DarojaAI/gcp-dbt-terraform/commit/1ce99b822cc04d1aae453b541973670c48ae8bb2))

## [1.1.0](https://github.com/DarojaAI/gcp-dbt-terraform/compare/v1.0.1...v1.1.0) (2026-05-01)


### Features

* add plannable basic example as CI fixture ([f7c3a14](https://github.com/DarojaAI/gcp-dbt-terraform/commit/f7c3a14e918b48ee355d872b4e3bfc7464386e04))
* add smoke probe, preflight docs, and CLAUDE.md updates ([3f32d54](https://github.com/DarojaAI/gcp-dbt-terraform/commit/3f32d5490f8013282afcb6b83668d9cf9be7eac6))
* add terraform test and preflight script ([2dc2a4b](https://github.com/DarojaAI/gcp-dbt-terraform/commit/2dc2a4b1896e1676985a2a9eea5e32d30fc9ff4f))
* add tflint validation to catch provider schema issues ([0339e67](https://github.com/DarojaAI/gcp-dbt-terraform/commit/0339e670818beff0dd4932a53de0c9b048b717d7))
* add variable descriptions and integrate checkov security scanning ([fbe02be](https://github.com/DarojaAI/gcp-dbt-terraform/commit/fbe02be7a23e586e2bc8a3801f80bac66fe5c1b8))


### Bug Fixes

* disable terraform_unused_declarations rule ([d8d664c](https://github.com/DarojaAI/gcp-dbt-terraform/commit/d8d664cbd27b04d40eb27db60af87f65f375daa5))
* init examples/basic in CI to avoid null provider error ([5003740](https://github.com/DarojaAI/gcp-dbt-terraform/commit/50037407a7e9396d7ac8ee2988b6df554e07fd11))
* remove provider block from module to support count/for_each ([881fbc6](https://github.com/DarojaAI/gcp-dbt-terraform/commit/881fbc6ea9249d605d91a4ca2dbcb8452edabe6a))
* run terraform test from examples/basic directory ([fec409f](https://github.com/DarojaAI/gcp-dbt-terraform/commit/fec409f4ab3bb9b1fef6cc956d0c38898d3156ff))
* use correct tflint_version parameter ([454cfea](https://github.com/DarojaAI/gcp-dbt-terraform/commit/454cfea71a9d224b125f7abdcd24d3e7bd3354a7))
* wire job_* variables to nested module ([1ce99b8](https://github.com/DarojaAI/gcp-dbt-terraform/commit/1ce99b822cc04d1aae453b541973670c48ae8bb2))
