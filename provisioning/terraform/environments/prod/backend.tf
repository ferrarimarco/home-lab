terraform {
  backend "gcs" {
    bucket = "ferrarimarco-iac-terraform-state"
    prefix = "terraform/state/environments/prod"
  }
}
