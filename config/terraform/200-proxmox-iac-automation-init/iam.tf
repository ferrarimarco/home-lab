module "proxmox-iam-automation-pve1" {
  source = "../modules/proxmox-iam-automation"

  providers = {
    proxmox = proxmox.pve1
  }
}
