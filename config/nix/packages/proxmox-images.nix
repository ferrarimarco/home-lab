{
  pkgs,
  nixosInstaller,
  nixosLxcBootstrap,
}:

# Aggregate the image artifacts that Terraform uploads to Proxmox behind a
# single output, so one `nix build .#proxmox-images` stages both the installer
# ISO (result/iso) and the LXC template (result/tarball) without the
# individual builds competing for the `result` symlink.
pkgs.runCommand "proxmox-images" { } ''
  mkdir --parents "$out"
  ln --symbolic ${nixosInstaller}/iso "$out/iso"
  ln --symbolic ${nixosLxcBootstrap}/tarball "$out/tarball"
''
