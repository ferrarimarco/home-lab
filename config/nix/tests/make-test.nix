{
  pkgs,
  lib,
  hostConfiguration,
  extraConfig ? { },
  extraTestScript ? "",
  ...
}@args:

let
  # Strip out the test-harness arguments so we can pass everything else down
  passedArgs = builtins.removeAttrs args [
    "pkgs"
    "lib"
    "hostConfiguration"
    "extraConfig"
    "extraTestScript"
  ];

  # Combine default fallback mocks with whatever your flake explicitly passes
  nodeArgs = {
    inputs = { };
    self = { };
  }
  // passedArgs;

  eval = pkgs.testers.nixosTest {
    name = "eval-host-name";
    nodes.machine = {
      _module.args = nodeArgs;
      imports = [ hostConfiguration ];
      networking.hostName = lib.mkDefault "unnamed-host";
    };
    testScript = "";
  };

  inherit (eval.nodes.machine.networking) hostName;
in
pkgs.testers.nixosTest {
  name = "${hostName}-test";

  nodes.machine =
    { config, ... }:
    {
      _module.args = nodeArgs;

      imports = [
        hostConfiguration
        extraConfig
      ];

      # Ensure the test runs in a predictable environment
      # Sometimes modules might try to override the hostname; forcing it ensures
      # the test derivation name and the internal OS state remain synced.
      networking.hostName = lib.mkForce hostName;

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
      node_config = nodes.machine;

      # Verify SSH port if openssh service is enabled
      sshCheck = lib.optionalString node_config.services.openssh.enable ''
        machine.wait_for_open_port(22)
      '';

      # Verify QEMU guest agent if guest agent service is enabled
      qemuAgentCheck = lib.optionalString node_config.services.qemuGuest.enable ''
        machine.wait_for_file("/dev/virtio-ports/org.qemu.guest_agent.0")
        machine.wait_for_unit("qemu-guest-agent.service")
      '';
    in
    ''
      # Boot check (common to all hosts)
      machine.wait_for_unit("multi-user.target")

      # Dynamic service assertions
      ${sshCheck}
      ${qemuAgentCheck}

      # Host-specific custom assertions (if any)
      ${extraTestScript}
    '';
}
