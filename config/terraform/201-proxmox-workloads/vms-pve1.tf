resource "proxmox_virtual_environment_vm" "vm_100" {
  name          = "hl01"
  description   = "Managed by Terraform"
  node_name     = "pve1"
  vm_id         = 100
  scsi_hardware = "virtio-scsi-single"

  agent {
    enabled = true
  }

  bios            = "ovmf"
  keyboard_layout = "en-us"
  machine         = "q35"

  cpu {
    cores = 2
    type  = "host"
  }

  memory {
    dedicated = 8192
    floating  = 0
  }

  network_device {
    bridge       = "vmbr0"
    disconnected = false
    firewall     = true
    mac_address  = "BC:24:11:D4:F6:64"
    model        = "virtio"
    mtu          = 0
    queues       = 0
    rate_limit   = 0
    trunks       = null
    vlan_id      = 0
  }

  disk {
    datastore_id = "local-zfs"
    discard      = "on"
    interface    = "scsi0"
    iothread     = true
    ssd          = true
  }

  disk {
    aio               = "io_uring"
    backup            = true
    cache             = "none"
    datastore_id      = "rpool-sata"
    discard           = "on"
    file_format       = "raw"
    interface         = "scsi1"
    iothread          = true
    path_in_datastore = "vm-100-disk-0"
    replicate         = true
    size              = 113
    ssd               = true
  }

  disk {
    aio               = "io_uring"
    backup            = true
    cache             = "none"
    datastore_id      = "rpool-usb-1"
    discard           = "ignore"
    file_format       = "raw"
    interface         = "scsi2"
    iothread          = true
    path_in_datastore = "vm-100-disk-0"
    replicate         = true
    size              = 885
    ssd               = false
  }

  efi_disk {
    datastore_id      = "local-zfs"
    file_format       = "raw"
    pre_enrolled_keys = false
    type              = "4m"
  }

  # Coral PCI
  hostpci {
    device = "hostpci0"
    id     = "0000:03:00"
    pcie   = true
    rombar = true
    xvga   = false
  }

  # iGPU
  hostpci {
    device = "hostpci1"
    id     = "0000:00:02"
    pcie   = true
    rombar = true
    xvga   = true
  }

  initialization {
    datastore_id         = "local-zfs"
    interface            = "ide2"
    network_data_file_id = "local:snippets/cloud-init-hl01-network.yaml"
    user_data_file_id    = "local:snippets/cloud-init-hl01-user-data.yaml"
  }

  operating_system {
    type = "l26"
  }
}
