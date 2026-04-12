variable "proxmox_virtual_environment_api_endpoint" {
  description = "Proxmox Virtual Environment API endpoint URL"
  type        = string
}

variable "proxmox_virtual_environment_api_token" {
  default     = null
  description = "Proxmox Virtual Environment API authentication token"
  sensitive   = true
  type        = string
}

variable "proxmox_virtual_environment_insecure" {
  default     = false
  description = "Set to true to disable API endpoint certificate validation. Useful for development environment or self-signed certificates"
  type        = bool
}

variable "proxmox_virtual_environment_node_hostname" {
  description = "Hostname of the Proxmox Virtual Environment node"
  type        = string
}

variable "proxmox_virtual_environment_username" {
  default     = "root@pam"
  description = "Proxmox Virtual Environment API username"
  sensitive   = true
  type        = string
}

variable "proxmox_virtual_environment_password" {
  default     = null
  description = "Proxmox Virtual Environment API password"
  sensitive   = true
  type        = string
}
