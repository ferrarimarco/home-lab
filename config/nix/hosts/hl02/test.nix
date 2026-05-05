{ pkgs, ... }:

pkgs.testers.nixosTest {
  name = "hl02-test";

  nodes.machine =
    { ... }:
    {
      imports = [
        ./configuration.nix
      ];

      virtualisation.qemu.options = [
        "-device virtio-serial"
        "-device virtserialport,chardev=qga0,name=org.qemu.guest_agent.0"
        "-chardev socket,path=/tmp/qga.sock,server=on,wait=off,id=qga0"
      ];
    };

  testScript = ''
    machine.wait_for_unit("multi-user.target")
    machine.wait_for_open_port(22)
    machine.succeed("systemctl is-active qemu-guest-agent")
  '';
}
