{ lib, modulesPath, ... }:

{
  imports = [
    (modulesPath + "/virtualisation/proxmox-lxc.nix")
  ];

  proxmoxLXC = {
    enable = true;

    # Workload-tunable options are set with lib.mkDefault so service roles
    # and host configurations can override them with plain values.
    privileged = lib.mkDefault false;

    # With these disabled, the container consumes what PVE's nixos ostype
    # hooks write into it at start: the systemd-networkd configuration and
    # /etc/hostname. Hosts that pin networking.hostName (every comin
    # workload) must override manageHostName to true: the upstream module
    # otherwise forces networking.hostName to "" and comin asserts at build
    # time that it is non-empty. See the hostname note in the proxmox-lxc
    # spec.
    manageNetwork = lib.mkDefault false;
    manageHostName = lib.mkDefault false;
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
