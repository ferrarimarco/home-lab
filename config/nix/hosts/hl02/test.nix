{ pkgs, ... }:

pkgs.testers.nixosTest {
  name = "hl02-test";

  nodes.machine =
    { ... }:
    {
      imports = [
        ./configuration.nix
      ];

      # Provision a mock virtio serial port for the guest agent.
      #
      # 1. Enable virtio-serial device in QEMU.
      # 2. Create a virtserialport and map it to the guest agent channel name
      #    ('org.qemu.guest_agent.0') that the udev rules look for.
      # 3. Back it with a 'null' chardev. We use 'null' instead of 'socket' (with
      #    a physical file path like /tmp/qga.sock) to avoid file permission/conflict
      #    issues when running inside the sandboxed Nix builder environment (e.g. GHA).
      virtualisation.qemu.options = [
        "-device virtio-serial"
        "-device virtserialport,chardev=qga0,name=org.qemu.guest_agent.0"
        "-chardev null,id=qga0"
      ];
    };

  testScript = ''
    # Wait for standard boot sequence to complete
    machine.wait_for_unit("multi-user.target")
    machine.wait_for_open_port(22)

    # Wait for the hardware device to be populated by udev
    machine.wait_for_file("/dev/virtio-ports/org.qemu.guest_agent.0")

    # Now it is safe to wait for the unit, or verify it started

    # The qemu-guest-agent service is triggered asynchronously by udev rules
    # once the virtual serial device is detected during boot.
    #
    # Rather than instantly running an assertion (which can fail due to udev
    # processing delays), we use 'wait_for_unit' to wait for the service to start.
    machine.wait_for_unit("qemu-guest-agent.service")
  '';
}
