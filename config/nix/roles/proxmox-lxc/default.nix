{ lib, modulesPath, ... }:

{
  imports = [
    (modulesPath + "/virtualisation/proxmox-lxc.nix")
  ];

  proxmoxLXC = {
    enable = true;
    privileged = false;
    manageNetwork = false; # Let systemd-networkd consume network contexts from PVE
    manageHostName = false; # Let the container extract its identity from /etc/hostname
  };

  # Suppress errors from standard hardware components that do not exist inside a container
  services.udev.enable = lib.mkForce false;
  powerManagement.enable = lib.mkForce false;

  # LXC containers share the host kernel; do not try to load kernel modules or modify sysctls
  boot.kernel.enable = lib.mkForce false;
  boot.modprobeConfig.enable = lib.mkForce false;

  # Avoid service failures
  # systemd-logind fails to monitor when it runs inside unprivileged containers
  systemd.services.systemd-logind.serviceConfig.Restart = "on-failure";

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
