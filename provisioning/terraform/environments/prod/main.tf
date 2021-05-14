provider "google" {
  region = var.google_default_region
  zone   = var.google_default_zone
}

data "google_organization" "main_organization" {
  domain = var.google_organization_domain
}

locals {
  compute_engine_public_keys_directory_path = "${local.public_keys_directory_path}/${var.configuration_compute_engine_keys_directory_name}"
  container_image_registry_url              = "${var.default_container_registry_url}/${module.iac-pipeline.container_registry_project}"
  iot_core_public_keys_directory_path       = "${local.public_keys_directory_path}/${var.configuration_iot_core_keys_directory_name}"
  main_dns_zone                             = "${var.main_dns_zone_prefix}.${data.google_organization.main_organization.domain}"
  public_keys_directory_path                = var.configuration_public_keys_directory_name

  # To get environment-specific configuration
  terraform_environment_configuration_directory_path = "${var.configuration_directory_name}/${var.configuration_terraform_environments_directory_name}/${var.configuration_terraform_environment_name}"
}

module "iac-pipeline" {
  source                                             = "../../modules/iac-pipeline"
  cloud_build_trigger_repository_name                = var.cloud_build_trigger_repository_name
  cloud_build_trigger_repository_owner               = var.cloud_build_trigger_repository_owner
  compute_engine_keys_directory_path                 = local.compute_engine_public_keys_directory_path
  google_billing_account_id                          = var.google_billing_account_id
  google_project_id                                  = var.google_iac_project_id
  google_organization_id                             = data.google_organization.main_organization.org_id
  terraform_environment_configuration_directory_path = local.terraform_environment_configuration_directory_path
}

module "iot" {
  source                              = "../../modules/iot"
  configuration_bucket_name           = module.iac-pipeline.configuration_bucket_name
  configuration_bucket_self_link      = module.iac-pipeline.configuration_bucket_self_link
  google_organization_id              = data.google_organization.main_organization.org_id
  google_project_id                   = var.google_iot_project_id
  iot_core_public_keys_directory_path = local.iot_core_public_keys_directory_path
  iot_core_public_keys_storage_prefix = "${local.terraform_environment_configuration_directory_path}/${local.iot_core_public_keys_directory_path}"
}

module "configuration" {
  source            = "../../modules/configuration"
  google_project_id = var.google_configuration_project_id
  main_dns_zone     = local.main_dns_zone
}
