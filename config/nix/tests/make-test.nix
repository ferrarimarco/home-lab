{
  pkgs,
  hostConfiguration,
  extraConfig ? { },
  extraTestScript ? "",
}:

let
  # Shallow evaluation of configuration.nix to extract the hostname
  hostName = (import hostConfiguration { }).networking.hostName;
in
pkgs.testers.nixosTest {
  name = "${hostName}-test";

  nodes.machine =
    { config, lib, ... }:
    {
      imports = [
        hostConfiguration
        extraConfig
      ];

      # Dynamic VM hardware setup:
      # If the guest agent is enabled in the NixOS config, automatically
      # provision the virtual serial port hardware in QEMU.
      virtualisation.qemu.options = lib.mkIf config.services.qemuGuest.enable [
        "-device virtio-serial"
        "-device virtserialport,chardev=qga0,name=org.qemu.guest_agent.0"
        "-chardev null,id=qga0"
      ];
    };

  # Dynamic test script generation:
  # Inspects the evaluated system configuration and appends Python
  # assertions dynamically based on active services.
  testScript =
    { nodes, ... }:
    let
      config = nodes.machine.config;

      # Dynamically verify SSH port if openssh service is enabled
      sshCheck = if config.services.openssh.enable then ''
        machine.wait_for_open_port(22)
      '' else "";

      # Dynamically verify QEMU guest agent if guest agent service is enabled
      qemuAgentCheck = if config.services.qemuGuest.enable then ''
        machine.wait_for_file("/dev/virtio-ports/org.qemu.guest_agent.0")
        machine.wait_for_unit("qemu-guest-agent.service")
      '' else "";
    in
    ''
      # Standard boot check (common to all hosts)
      machine.wait_for_unit("multi-user.target")

      # Dynamic service assertions
      ${sshCheck}
      ${qemuAgentCheck}

      # Host-specific custom assertions (if any)
      ${extraTestScript}
    '';
}
