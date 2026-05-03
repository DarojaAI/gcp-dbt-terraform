# CI fixture: proves the artifacts bucket and IAM are wired correctly.

module "dbt_runner" {
  source = "../.."

  project_id  = "fake-project"
  environment = "ci"
  region      = "us-central1"
  repo_prefix = "rag-research"

  network_id    = "projects/fake-project/global/networks/fake-vpc"
  subnetwork_id = "projects/fake-project/regions/us-central1/subnetworks/fake-subnet"

  # checkov:skip=CKV_SECRET_6: This is a fake/test placeholder, not a real secret
  postgres_host            = "10.0.0.2"
  postgres_port            = 5432
  postgres_db              = "rag_taxonomy"
  postgres_user            = "rag_admin"
  postgres_password_secret = "projects/000000000000/secrets/fake-postgres-password/versions/latest"

  dbt_image_uri       = "gcr.io/fake-project/dbt:latest"
  wif_service_account = "github-actions@fake-project.iam.gserviceaccount.com"

  artifacts_bucket_name     = "fake-rag-research-ci-dbt-artifacts"
  artifacts_bucket_location = "US"
}
