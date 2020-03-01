locals {
  env = "prod"
}

provider "google" {}

module "iac-pipeline" {
  source = "../../modules/iac-pipeline"
}

module "iot" {
  source = "../../modules/iot"
}
