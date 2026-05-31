provider "proxmox" {
  alias = "pve1"

  endpoint = var.proxmox_virtual_environment_hosts["pve1"].api_endpoint
  insecure = var.proxmox_virtual_environment_hosts["pve1"].insecure

  # Authentication configuration
  # In order of precedence:
  # 1. API Token
  # 2. Auth Ticket
  # 3. Username/Password

  api_token = var.proxmox_virtual_environment_hosts_secrets["pve1"].api_token

  username = var.proxmox_virtual_environment_hosts_secrets["pve1"].username
  password = var.proxmox_virtual_environment_hosts_secrets["pve1"].password
}
