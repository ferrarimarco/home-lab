variable "proxmox_virtual_environment_api_endpoint" {
  description = "Proxmox Virtual Environment API endpoint URL."
  type        = string
}

variable "proxmox_virtual_environment_api_token" {
  description = "Proxmox Virtual Environment API authentication token."
  type        = string
}

variable "proxmox_virtual_environment_insecure" {
  default     = false
  description = "Set to true to disable API endpoint certificate validation. Useful for development environment or self-signed certificates."
  type        = bool
}
