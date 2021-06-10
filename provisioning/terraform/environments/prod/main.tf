provider "google" {
  region = var.google_default_region
  zone   = var.google_default_zone
}

data "google_organization" "main_organization" {
  domain = var.google_organization_domain
}

locals {
  main_dns_zone = "${var.main_dns_zone_prefix}.${data.google_organization.main_organization.domain}"
}

module "iac-pipeline" {
  source                    = "../../modules/iac-pipeline"
  google_billing_account_id = var.google_billing_account_id
  google_project_id         = var.google_iac_project_id
  google_organization_id    = data.google_organization.main_organization.org_id
}

module "configuration" {
  source            = "../../modules/configuration"
  google_project_id = var.google_configuration_project_id
  main_dns_zone     = local.main_dns_zone
}
