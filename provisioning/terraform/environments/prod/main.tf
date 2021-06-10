provider "google" {
  region = var.google_default_region
  zone   = var.google_default_zone
}

data "google_organization" "main_organization" {
  domain = var.google_organization_domain
}

locals {
  container_image_registry_url = "${var.default_container_registry_url}/${module.iac-pipeline.container_registry_project}"
  main_dns_zone                = "${var.main_dns_zone_prefix}.${data.google_organization.main_organization.domain}"

  # To get environment-specific configuration
  terraform_environment_configuration_directory_path = "${var.configuration_directory_name}/${var.configuration_terraform_environments_directory_name}/${var.configuration_terraform_environment_name}"
}

module "iac-pipeline" {
  source                                             = "../../modules/iac-pipeline"
  cloud_build_trigger_repository_name                = var.cloud_build_trigger_repository_name
  cloud_build_trigger_repository_owner               = var.cloud_build_trigger_repository_owner
  google_billing_account_id                          = var.google_billing_account_id
  google_project_id                                  = var.google_iac_project_id
  google_organization_id                             = data.google_organization.main_organization.org_id
  terraform_environment_configuration_directory_path = local.terraform_environment_configuration_directory_path
}

module "configuration" {
  source            = "../../modules/configuration"
  google_project_id = var.google_configuration_project_id
  main_dns_zone     = local.main_dns_zone
}
