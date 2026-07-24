variable "nas_container_bind_mounts" {
  description = "Per-node ZFS dataset bind mounts for the NAS LXC containers (host path to in-container path)."
  type = map(list(object({
    host_path      = string
    container_path = string
  })))
  default = {
    "pve1" = [
      {
        host_path      = "/rpool-sata/media"
        container_path = "/mnt/shared/media"
      },
      {
        host_path      = "/rpool-sata/backups"
        container_path = "/mnt/shared/backups"
      },
    ]
    "pve2" = [
      {
        host_path      = "/tank-hdd/media"
        container_path = "/mnt/shared/media"
      },
      {
        host_path      = "/tank-hdd/backups"
        container_path = "/mnt/shared/backups"
      },
    ]
  }
}

variable "proxmox_virtual_environment_hosts" {
  description = "A map of Proxmox hosts and their API connection details."
  type = map(object({
    api_endpoint = string
    insecure     = optional(bool, false)
    node_name    = string
    ssh_username = optional(string, null)
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
