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
  name               = "${var.google_iac_project_id}-terraform-state"
  location           = "US"
  bucket_policy_only = true

  versioning {
    enabled = true
  }
}

locals {
  compute_engine_development_workstation_ssh_public_key_file_path = "${local.compute_engine_public_keys_directory_path}/${var.configuration_compute_engine_development_workstation_ssh_public_key_file_name}"
  compute_engine_public_keys_directory_path                       = "${local.public_keys_directory_path}/${var.configuration_compute_engine_keys_directory_name}"
  iot_core_public_keys_directory_path                             = "${local.public_keys_directory_path}/${var.configuration_iot_core_keys_directory_name}"
  iot_core_smart_desk_public_key_file_path                        = "${local.iot_core_public_keys_directory_path}/${var.configuration_iot_core_smart_desk_public_key_file_name}"
  public_keys_directory_path                                      = "${var.configuration_directory_name}/${var.configuration_public_keys_directory_name}"
}

module "iac-pipeline" {
  source                             = "../../modules/iac-pipeline"
  compute_engine_keys_directory_path = local.compute_engine_public_keys_directory_path
  iot_core_keys_directory_path       = local.iot_core_public_keys_directory_path
  google_project_id                  = var.google_iac_project_id
  google_project_number              = google_project.ferrarimarco_iac.number
  google_organization_id             = data.google_organization.ferrari_how.org_id
}

module "iot" {
  source                                   = "../../modules/iot"
  iot_core_smart_desk_public_key_file_path = local.iot_core_smart_desk_public_key_file_path
  google_organization_id                   = data.google_organization.ferrari_how.org_id
  google_project_billing_account_id        = var.google_billing_account_id
  google_project_id                        = var.google_iot_project_id
}

module "development-workspace" {
  source                                                          = "../../modules/development-workspace"
  compute_engine_development_workstation_ssh_public_key_file_path = local.compute_engine_development_workstation_ssh_public_key_file_path
  development_workstation_machine_type                            = var.development_workstation_machine_type
  development_workstation_min_cpu_platform                        = var.development_workstation_min_cpu_platform
  development_workstation_name                                    = var.development_workstation_name
  development_workstation_ssh_user                                = var.development_workstation_ssh_user
  google_organization_id                                          = data.google_organization.ferrari_how.org_id
  google_project_id                                               = var.google_iot_project_id
}
