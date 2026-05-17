terraform {
  required_version = "1.14.0"

  required_providers {
    local = {
      source  = "hashicorp/local"
      version = "~> 2.8.0"
    }


    # https://registry.terraform.io/providers/bpg/proxmox
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.100.0"
    }

    random = {
      source  = "hashicorp/random"
      version = "~> 3.8.1"
    }
  }
}
