locals {
  env = "prod"
}

provider "google" {}

data "google_organization" "ferrari_how" {
  domain = "ferrari.how"
}

data "google_client_config" "current" {
}

module "iac-pipeline" {
  source          = "../../modules/iac-pipeline"
  iac_project_id  = data.google_client_config.current.project
  organization_id = data.google_organization.ferrari_how.id
}

# module "iot" {
#   source          = "../../modules/iot"
#   organization_id = data.google_organization.ferrari_how.id
# }
