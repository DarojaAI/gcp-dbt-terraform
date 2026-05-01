# CI fixture: proves the root module composes against fake but well-formed
# inputs. Never deploy this — every value is a placeholder.

module "dbt_runner" {
  source = "../.."

  project_id  = "fake-project"
  environment = "ci"
  region      = "us-central1"
  repo_prefix = "rag-research"

  # VPC — fake but well-formed self-links
  network_id    = "projects/fake-project/global/networks/fake-vpc"
  subnetwork_id = "projects/fake-project/regions/us-central1/subnetworks/fake-subnet"

  # Postgres — fake values, full Secret Manager path format
  # checkov:skip=CKV_SECRET_6: This is a fake/test placeholder, not a real secret
  postgres_host            = "10.0.0.2"
  postgres_port            = 5432
  postgres_db              = "rag_taxonomy"
  postgres_user            = "rag_admin"
  postgres_password_secret = "projects/000000000000/secrets/fake-postgres-password/versions/latest"

  # Image — fake GCR URI
  dbt_image_uri = "gcr.io/fake-project/dbt:latest"

  # WIF — fake SA email
  wif_service_account = "github-actions@fake-project.iam.gserviceaccount.com"

  labels = {
    component  = "dbt"
    managed_by = "terraform"
    fixture    = "true"
  }
}
