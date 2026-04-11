provider "proxmox" {
  endpoint = var.proxmox_virtual_environment_api_endpoint
  insecure = var.proxmox_virtual_environment_insecure

  # Authentication configuration
  # In order of precedence:
  # 1. API Token
  # 2. Auth Ticket
  # 3. Username/Password

  api_token = var.proxmox_virtual_environment_api_token

  username = var.proxmox_virtual_environment_username
  password = var.proxmox_virtual_environment_password
}
