resource "proxmox_virtual_environment_container" "nas_pve1" {
  provider = proxmox.pve1

  description  = "Managed by Terraform - NixOS LXC NAS"
  node_name    = var.proxmox_virtual_environment_hosts["pve1"].node_name
  vm_id        = 200
  unprivileged = false # Privileged: bind mounts keep host UID/GID (no idmap)
  started      = true

  features {
    nesting = true
  }

  cpu {
    cores = 2
  }

  memory {
    dedicated = 2048
    swap      = 512
  }

  network_interface {
    name        = "eth0"
    bridge      = "vmbr0"
    mac_address = "BC:24:11:0C:A3:DB"
  }

  disk {
    datastore_id = "local-zfs"
    size         = 8 # GB - OS rootfs only; workload data is bind-mounted
  }

  operating_system {
    template_file_id = proxmox_virtual_environment_file.nixos_lxc_template_pve1.id
    # Selects PVE's native NixOS setup hooks, which write the container's
    # systemd-networkd configuration and /etc/hostname at start.
    type = "nixos"
  }

  initialization {
    hostname = "nas-pve1"

    ip_config {
      ipv4 {
        address = "dhcp"
      }
    }
  }

  # Bind mounts for ZFS datasets, parameterized via var.nas_container_bind_mounts
  dynamic "mount_point" {
    for_each = var.nas_container_bind_mounts["pve1"]
    content {
      volume = mount_point.value.host_path
      path   = mount_point.value.container_path
    }
  }

  # Persistent Samba state to survive container recreations. The host-side
  # directory must exist before the container first starts; see the NAS spec,
  # section 11.2.
  mount_point {
    volume = "/var/lib/samba-state/nas-pve1"
    path   = "/var/lib/samba"
  }
}
