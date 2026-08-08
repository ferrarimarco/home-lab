locals {
  nix_root_path = "${path.module}/../../../config/nix"

  # Use a pattern to match "nixos-minimal....x86_64-linux.iso" files because
  # generated ISO files have dates and commit hash as part of their name.
  # Example: nixos-minimal-25.11.20260417.c7f4703-x86_64-linux.iso
  nixos_installer_iso_relative_path = one(fileset(local.nix_root_path, "result/iso/nixos-minimal*x86_64-linux.iso"))

  # Use a pattern to match the generated tarball because its name embeds
  # the NixOS label (tags, release, date, and commit hash). The versioned
  # name also means a rebuilt template changes the source path and forces
  # a re-upload; a stable name would never re-upload.
  # Example: nixos-image-lxc-proxmox-25.11.20260417.c7f4703-x86_64-linux.tar.xz
  nixos_lxc_template_relative_path = one(fileset(local.nix_root_path, "result/tarball/nixos-image-*-x86_64-linux.tar.xz"))

  # Any nix build in config/nix repoints the shared 'result' symlink, so a
  # missing artifact usually means another build clobbered the staged images.
  missing_artifact_remediation = "Stage the image artifacts by running 'nix build .#proxmox-images' from config/nix (see the proxmox-lxc spec, section 5.4), then re-run this stack."

  nixos_installer_iso_error_message = "NixOS installer ISO not found: nothing matches result/iso/nixos-minimal*x86_64-linux.iso under ${local.nix_root_path}. ${local.missing_artifact_remediation}"
  nixos_lxc_template_error_message  = "NixOS LXC template not found: nothing matches result/tarball/nixos-image-*-x86_64-linux.tar.xz under ${local.nix_root_path}. ${local.missing_artifact_remediation}"
}

resource "proxmox_virtual_environment_file" "nixos_installer_x86_64_iso_pve1" {
  provider = proxmox.pve1

  content_type = "iso"
  datastore_id = "local"
  node_name    = var.proxmox_virtual_environment_hosts["pve1"].node_name

  source_file {
    # coalesce keeps this expression evaluable when the artifact is missing,
    # so the precondition below can report the actionable error instead of a
    # generic null-interpolation failure.
    path = "${local.nix_root_path}/${coalesce(local.nixos_installer_iso_relative_path, "missing")}"
  }

  lifecycle {
    precondition {
      condition     = local.nixos_installer_iso_relative_path != null
      error_message = local.nixos_installer_iso_error_message
    }
  }
}

resource "proxmox_virtual_environment_file" "nixos_installer_x86_64_iso_pve2" {
  provider = proxmox.pve2

  content_type = "iso"
  datastore_id = "local"
  node_name    = var.proxmox_virtual_environment_hosts["pve2"].node_name

  source_file {
    path = "${local.nix_root_path}/${coalesce(local.nixos_installer_iso_relative_path, "missing")}"
  }

  lifecycle {
    precondition {
      condition     = local.nixos_installer_iso_relative_path != null
      error_message = local.nixos_installer_iso_error_message
    }
  }
}

resource "proxmox_virtual_environment_file" "nixos_lxc_template_pve1" {
  provider = proxmox.pve1

  content_type = "vztmpl"
  datastore_id = "local"
  node_name    = var.proxmox_virtual_environment_hosts["pve1"].node_name

  source_file {
    path      = "${local.nix_root_path}/${coalesce(local.nixos_lxc_template_relative_path, "missing")}"
    file_name = "nixos-lxc-pve1.tar.xz"
  }

  lifecycle {
    precondition {
      condition     = local.nixos_lxc_template_relative_path != null
      error_message = local.nixos_lxc_template_error_message
    }
  }
}

resource "proxmox_virtual_environment_file" "nixos_lxc_template_pve2" {
  provider = proxmox.pve2

  content_type = "vztmpl"
  datastore_id = "local"
  node_name    = var.proxmox_virtual_environment_hosts["pve2"].node_name

  source_file {
    path      = "${local.nix_root_path}/${coalesce(local.nixos_lxc_template_relative_path, "missing")}"
    file_name = "nixos-lxc-pve2.tar.xz"
  }

  lifecycle {
    precondition {
      condition     = local.nixos_lxc_template_relative_path != null
      error_message = local.nixos_lxc_template_error_message
    }
  }
}
