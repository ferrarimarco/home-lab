variable "proxmox_virtual_environment_hosts" {
  description = "A map of Proxmox hosts and their API connection details."
  type = map(object({
    api_endpoint = string
    insecure     = optional(bool, false)
    node_name    = string
  }))
}

variable "proxmox_virtual_environment_hosts_secrets" {
  description = "A map of Proxmox hosts and their secrets."
  type = map(object({
    api_token = optional(string)
    password  = optional(string)
    username  = optional(string, "root@pam")
  }))
  sensitive = true
}
