{ inputs, ... }:

{
  imports = [
    inputs.disko.nixosModules.disko

    ../../roles/common
    ../../roles/proxmox-vm
    ../../roles/zfs
    # TODO
    # ./hardware.nix
    ./disko.nix
  ];

  networking.hostId = "92bbb1e6";
  networking.hostName = "nas1";
}
