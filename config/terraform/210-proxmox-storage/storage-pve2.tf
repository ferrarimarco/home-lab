resource "proxmox_storage_directory" "local_directory_pve2" {
  provider = proxmox.pve2

  id   = "local"
  path = "/var/lib/vz"

  shared  = false
  disable = false

  nodes = []

  content = ["backup", "import", "iso", "vztmpl"]
}

resource "proxmox_storage_zfspool" "tank_hdd_pve2" {
  provider = proxmox.pve2

  id       = "tank-hdd"
  zfs_pool = "tank-hdd"

  disable        = false
  thin_provision = true

  nodes = [
    "pve2"
  ]

  content = ["images", "rootdir"]
}

resource "proxmox_storage_zfspool" "tank_hdd_scratch" {
  provider = proxmox.pve2

  id       = "tank-hdd-scratch"
  zfs_pool = "tank-hdd-scratch"

  disable = false

  nodes = ["pve2"]

  content = ["images", "rootdir"]
}

resource "proxmox_storage_zfspool" "tank_ssd_scratch" {
  provider = proxmox.pve2

  id       = "tank-ssd-scratch"
  zfs_pool = "tank-ssd-scratch"

  disable = false

  nodes = ["pve2"]

  content = ["images", "rootdir"]
}

resource "proxmox_storage_lvmthin" "local_lvm" {
  provider = proxmox.pve2

  id           = "local-lvm"
  volume_group = "pve"
  thin_pool    = "data"

  content = ["images", "rootdir"]
}
