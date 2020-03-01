locals {
  env = "prod"
}

provider "google" {}

module "iac-pipeline" {
  source = "../../modules/iac-pipeline"
}

module "iac-pipeline" {
  source = "../../modules/iot"
}
