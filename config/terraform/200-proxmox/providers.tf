provider "proxmox" {
  api_token = var.proxmox_virtual_environment_api_token
  endpoint  = var.proxmox_virtual_environment_api_endpoint
  insecure  = var.proxmox_virtual_environment_insecure
}
