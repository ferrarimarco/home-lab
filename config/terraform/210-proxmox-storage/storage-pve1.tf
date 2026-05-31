resource "proxmox_storage_directory" "local_directory" {
  provider = proxmox.pve1

  id   = "local"
  path = "/var/lib/vz"

  shared  = false
  disable = false

  nodes = []

  content = ["backup", "iso", "vztmpl"]
}

resource "proxmox_storage_zfspool" "local_zfs" {
  provider = proxmox.pve1

  id       = "local-zfs"
  zfs_pool = "rpool/data"

  disable        = false
  thin_provision = true

  nodes = []

  content = ["images", "rootdir"]
}

resource "proxmox_storage_zfspool" "rpool_sata" {
  provider = proxmox.pve1

  id       = "rpool-sata"
  zfs_pool = "rpool-sata"

  disable = false

  nodes = ["pve1"]

  content = ["images", "rootdir"]
}

resource "proxmox_storage_zfspool" "rpool_usb_1" {
  provider = proxmox.pve1

  id       = "rpool-usb-1"
  zfs_pool = "rpool-usb-1"

  disable = false

  nodes = ["pve1"]

  content = ["images", "rootdir"]
}
