locals {
  nix_root_path = "${path.module}/../../../config/nix"
}

resource "proxmox_virtual_environment_file" "nixos_installer_x86_64_iso_pve1" {
  provider = proxmox.pve1

  content_type = "iso"
  datastore_id = "local"
  node_name    = var.proxmox_virtual_environment_hosts["pve1"].node_name

  source_file {
    # Use a regex to match "nixos-minimal....x86_64-linux.iso" files because
    # generated ISO files have dates and commit hash as part of their name.
    # Example: nixos-minimal-25.11.20260417.c7f4703-x86_64-linux.iso
    path = "${local.nix_root_path}/${one(fileset(local.nix_root_path, "result/iso/nixos-minimal*x86_64-linux.iso"))}"
  }
}
