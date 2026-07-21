{ pkgs, self, ... }:

let
  inherit (pkgs.stdenv.hostPlatform) system;
  lxcBootstrap = self.packages.${system}.nixos-lxc-bootstrap;
in
{
  extraConfig = {
    # Import the exact module set the nixos-lxc-bootstrap package is built from,
    # so this fixture actually exercises the package (not just the proxmox-lxc
    # role). The QEMU root-filesystem mock and other LXC->VM overrides are
    # injected by the test harness (make-test.nix) whenever the proxmox-lxc
    # options are present.
    imports = lxcBootstrap.modules;

    virtualisation.memorySize = 1024;
    virtualisation.graphics = false;
  };

  # Unique test assertions specific only to the LXC container profile
  extraTestScript = ''
    print("--- LXC Unique Assertions ---")
    machine.succeed("systemctl is-enabled systemd-networkd")
  '';
}
