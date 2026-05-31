variable "proxmox_virtual_environment_hosts" {
  description = "A map of Proxmox hosts and their API connection details."

  # Care only about the keys, not the values
  type = map(any)
}
