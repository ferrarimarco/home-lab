{
  lib,
  pkgs,
  modulesPath,
  ...
}:

{
  imports = [
    # Built-in NixOS profile for QEMU/KVM guests
    # Ref: https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/profiles/qemu-guest.nix
    (modulesPath + "/profiles/qemu-guest.nix")
  ];

  # Standard VirtIO drivers for Proxmox
  boot.initrd.availableKernelModules = [
    "ahci"
    "usbhid"
    "sr_mod"
  ];

  # Enable the QEMU Guest Agent
  services.qemuGuest.enable = true;

  # Optimize for Proxmox Serial Console (xterm.js)
  boot.kernelParams = [ "console=ttyS0" ];

  # Bootloader for UEFI VMs (Proxmox OVMF)
  # Wrapped in mkDefault so a specific legacy-BIOS VM can override this to use GRUB if ever needed.
  boot.loader.systemd-boot.enable = lib.mkDefault true;
  boot.loader.efi.canTouchEfiVariables = lib.mkDefault true;

  # Prevent systemd-boot from keeping infinitely many old generations,
  # which can eventually fill up the small /boot EFI partition.
  boot.loader.systemd-boot.configurationLimit = lib.mkDefault 10;

  environment.systemPackages = with pkgs; [
    pciutils # Useful for debugging Proxmox passthrough
  ];
}
