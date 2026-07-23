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

resource "proxmox_virtual_environment_file" "nixos_lxc_template_pve1" {
  provider = proxmox.pve1

  content_type = "vztmpl"
  datastore_id = "local"
  node_name    = var.proxmox_virtual_environment_hosts["pve1"].node_name

  source_file {
    # Use a pattern to match the generated tarball because its name embeds
    # the NixOS label (tags, release, date, and commit hash). The versioned
    # name also means a rebuilt template changes the source path and forces
    # a re-upload; a stable name would never re-upload.
    # Example: nixos-image-lxc-proxmox-25.11.20260417.c7f4703-x86_64-linux.tar.xz
    path      = "${local.nix_root_path}/${one(fileset(local.nix_root_path, "result/tarball/nixos-image-*-x86_64-linux.tar.xz"))}"
    file_name = "nixos-lxc-pve1.tar.xz"
  }
}

resource "proxmox_virtual_environment_file" "nixos_lxc_template_pve2" {
  provider = proxmox.pve2

  content_type = "vztmpl"
  datastore_id = "local"
  node_name    = var.proxmox_virtual_environment_hosts["pve2"].node_name

  source_file {
    # See the pve1 template resource for the pattern rationale.
    path      = "${local.nix_root_path}/${one(fileset(local.nix_root_path, "result/tarball/nixos-image-*-x86_64-linux.tar.xz"))}"
    file_name = "nixos-lxc-pve2.tar.xz"
  }
}
