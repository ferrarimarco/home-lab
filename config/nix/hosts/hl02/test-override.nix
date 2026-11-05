{ pkgs, lib, ... }:

let
  # The real payload is a 550 MB download and cannot boot in the test
  # framework anyway; the mock image has the same shape and exercises the
  # same unpack, publish, and export path. Its hash is read from the
  # derivation's output (import from derivation), so it never has to be
  # pinned by hand.
  mockImage = pkgs.callPackage ../../tests/mock-netboot-image.nix { };
in
{
  extraConfig = {
    homeLab.netboot = {
      # The test VM's own address on its test network, so the proxy DHCP
      # range and the rendered boot configuration refer to a reachable
      # interface, and the checks fetch through it rather than loopback.
      serverAddress = lib.mkVMOverride "192.168.1.1";
      interface = lib.mkVMOverride "eth1";
      clientNetwork = lib.mkVMOverride "192.168.1.0/24";
      # Long enough to observe the export outliving the stop, short enough
      # to observe its removal.
      exportRemovalDelay = lib.mkVMOverride "5s";
      payloads.raspios-lite = {
        url = lib.mkVMOverride "file://${mockImage}/mock.img.xz";
        sha256 = lib.mkVMOverride (lib.fileContents "${mockImage}/sha256");
      };
    };
  };
}
