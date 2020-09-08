locals {
  env = "prod"
}

provider "google" {
  region = var.google_default_region
  zone   = var.google_default_zone
}

data "google_organization" "ferrari_how" {
  domain = var.google_organization_domain
}

resource "google_project" "ferrarimarco_iac" {
  billing_account = var.google_billing_account_id
  name            = var.google_iac_project_id
  project_id      = var.google_iac_project_id
  org_id          = data.google_organization.ferrari_how.org_id

  auto_create_network = false
}

resource "google_storage_bucket" "terraform_state" {
  name               = var.google_terraform_state_bucket_id
  location           = "US"
  bucket_policy_only = true

  versioning {
    enabled = true
  }
}

module "iac-pipeline" {
  source                                = "../../modules/iac-pipeline"
  google_project_id                     = var.google_iac_project_id
  google_project_number                 = google_project.ferrarimarco_iac.number
  google_organization_id                = data.google_organization.ferrari_how.org_id
  google_cloudbuild_key_rotation_period = var.google_cloudbuild_key_rotation_period
}

module "iot" {
  source                              = "../../modules/iot"
  google_organization_id              = data.google_organization.ferrari_how.org_id
  google_project_billing_account_id   = var.google_billing_account_id
  google_project_id                   = var.google_iot_project_id
  smart_desk_public_key_pem_file_path = "iot-core/public-keys/smart_desk.pem"
}
