terraform {
  required_version = "1.14.0"

  required_providers {
    local = {
      source  = "hashicorp/local"
      version = "2.8.0"
    }

    terraform = {
      source = "terraform.io/builtin/terraform"
    }
  }
}
