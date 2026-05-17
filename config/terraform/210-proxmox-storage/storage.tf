resource "proxmox_storage_directory" "local_directory" {
  id   = "local"
  path = "/var/lib/vz"

  shared  = false
  disable = false

  nodes = []

  content = ["backup", "iso", "vztmpl"]
}

resource "proxmox_storage_zfspool" "local_zfs" {
  id       = "local-zfs"
  zfs_pool = "rpool/data"

  disable        = false
  thin_provision = true

  nodes = []

  content = ["images", "rootdir"]
}

resource "proxmox_storage_zfspool" "rpool_sata" {
  id       = "rpool-sata"
  zfs_pool = "rpool-sata"

  disable = false

  nodes = ["pve1"]

  content = ["images", "rootdir"]
}

resource "proxmox_storage_zfspool" "rpool_usb_1" {
  id       = "rpool-usb-1"
  zfs_pool = "rpool-usb-1"

  disable = false

  nodes = ["pve1"]

  content = ["images", "rootdir"]
}
