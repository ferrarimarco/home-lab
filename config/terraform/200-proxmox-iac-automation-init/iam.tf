module "proxmox-iam-automation-pve1" {
  source = "../modules/proxmox-iam-automation"

  providers = {
    proxmox = proxmox.pve1
  }
}

module "proxmox-iam-automation-pve2" {
  source = "../modules/proxmox-iam-automation"

  providers = {
    proxmox = proxmox.pve2
  }
}
