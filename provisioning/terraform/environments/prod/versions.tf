terraform {
  required_version = ">= 0.13"

  required_providers {
    consul = {
      source  = "hashicorp/consul"
      version = "~> 2.10.1"
    }
    google = {
      source  = "hashicorp/google"
      version = "~> 3.47.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 3.47.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 1.3.2"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 1.13.3"
    }
    kubernetes-alpha = {
      source  = "hashicorp/kubernetes-alpha"
      version = "~> 0.2.1"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 3.0.0"
    }
  }
}
