terraform {
  required_version = "~> 0.12.29"

  required_providers {
    google      = "~> 3.39.0"
    google-beta = "~> 3.39.0"
    helm        = "~> 1.3.0"
    kubernetes  = "~> 1.13.2"
    random      = "~> 2.3.0"
    tls         = "~> 2.2.0"
  }
}
