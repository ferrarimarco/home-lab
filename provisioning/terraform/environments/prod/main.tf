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

module "iot" {
  source                            = "../../modules/iot"
  google_organization_id            = data.google_organization.ferrari_how.org_id
  google_project_billing_account_id = var.google_billing_account_id
  google_project_id                 = var.google_iot_project_id
}
