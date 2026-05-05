{ ... }:

{
  imports = [
    ../../roles/common
    ../../roles/proxmox-vm
  ];

  networking.hostId = "92bbb1e6";
  networking.hostName = "hl02";
  networking.useDHCP = true;

  system.stateVersion = "25.11";
}
