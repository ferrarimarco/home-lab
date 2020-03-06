terraform {
  backend "gcs" {
    bucket = "ferrarim-iac-terraform-state"
    prefix = "terraform/state/iac"
  }
}
