terraform {
  required_version = "1.14.0"

  required_providers {
    local = {
      source  = "hashicorp/local"
      version = "~> 2.9.0"
    }


    # https://registry.terraform.io/providers/bpg/proxmox
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.107.0"
    }

    random = {
      source  = "hashicorp/random"
      version = "~> 3.9.0"
    }
  }
}
