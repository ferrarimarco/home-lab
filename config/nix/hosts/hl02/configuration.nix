{ ... }:

{
  imports = [
    ../../roles/common
    ../../roles/proxmox-vm
    ../../roles/comin
    ../../roles/monitoring
    ../../roles/mosquitto
    ../../roles/netboot-server
  ];

  networking.hostId = "92bbb1e6";
  networking.hostName = "hl02";
  networking.useDHCP = true;

  # The boot server of the Network Boot Service specification: a declared
  # host network-boots its payload from this VM while its toggle,
  # `netboot-rescue@<host>`, is started, and boots from its own disk
  # otherwise. The role's options are its interface; the values below are
  # this VM's facts, the lab's addressing, and the hosts it serves.
  homeLab.netboot = {
    enable = true;

    # The address the clients reach this VM at. The proxy DHCP reply and the
    # rendered boot configuration (NFS root, cloud-init seed URL) carry it,
    # and a rescue in progress depends on it staying put, so it is the DHCP
    # reservation of the VM's interface on the gateway. The inventory records
    # the same address and interface, and the flake cannot read the
    # inventory: a change is made in both places.
    serverAddress = "10.0.0.5";

    # The interface facing the lab network: the firewall admits the boot
    # services (proxy DHCP, TFTP, NFS, HTTP) on it only.
    interface = "ens18";

    # The clients the NFS exports accept, in exports(5) syntax: the lab
    # network, as a second guard behind the firewall, since the exports are
    # root filesystems with root squashing off.
    clientNetwork = "10.0.0.0/8";

    # The hosts this server can boot, by the name their toggle and their
    # trees carry. A host names its platform (how it finds the server and
    # fetches its boot files) and its payload (what it runs once booted).
    # The payloads are declared by the role, with raspios-lite, the pinned
    # Raspberry Pi OS Lite image, as the one this lab uses.
    hosts.raspberrypi2 = {
      platform = "raspberry-pi";
      payload = "raspios-lite";
    };
  };

  system.stateVersion = "25.11";
}
