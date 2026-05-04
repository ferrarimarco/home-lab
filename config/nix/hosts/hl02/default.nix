{ inputs, ... }:

{
  imports = [
    inputs.disko.nixosModules.disko

    ../../roles/common
    ../../roles/proxmox-vm
    ../../roles/ext4
    ./hardware.nix
    ./disko.nix
  ];

  networking.hostId = "92bbb1e6";
  networking.hostName = "hl02";
}
