locals {
  env = "prod"
}

provider "google" {}

module "iac-pipeline" {
  source = "../../modules/iac-pipeline"
}
