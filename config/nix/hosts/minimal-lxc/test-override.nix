{ lib, ... }:

{
  extraConfig = {
    imports = [
      ../../roles/proxmox-lxc
    ];

    # Override: QEMU requires a root filesystem layout to orchestrate the test VM.
    # We provide a mock mount point here so it can pass the kernel boot boundary.
    fileSystems."/" = lib.mkVMOverride {
      device = "/dev/root";
      fsType = "ext4";
    };

    virtualisation.memorySize = 1024;
    virtualisation.graphics = false;
  };

  # Unique test assertions specific only to the LXC container profile
  extraTestScript = ''
    print("--- LXC Unique Assertions ---")
    machine.succeed("systemctl is-enabled systemd-networkd")
  '';
}
