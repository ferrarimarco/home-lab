terraform {
  required_version = "~> 0.12.29"

  required_providers {
    google      = "~> 3.39.0"
    google-beta = "~> 3.39.0"
    kubernetes  = "~> 1.13.2"
  }
}
