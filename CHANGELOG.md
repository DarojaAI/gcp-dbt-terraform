# Changelog

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
