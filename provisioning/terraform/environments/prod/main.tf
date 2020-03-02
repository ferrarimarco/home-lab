locals {
  env = "prod"
}

provider "google" {}

data "google_organization" "org" {
  domain = "ferrari.how"
}

module "iac-pipeline" {
  source          = "../../modules/iac-pipeline"
  organization_id = data.google_organization.org.id
}

module "iot" {
  source          = "../../modules/iot"
  organization_id = data.google_organization.org.id
}
