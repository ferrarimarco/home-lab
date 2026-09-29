_: {
  imports = [
    ../../roles/common
    ../../roles/nas
    ../../roles/comin
  ];

  # Required per-host value; a host may also add its own shares (see the NAS
  # spec, section 5.1).
  networking.hostName = "nas-pve1";

  # Syncthing: the lab's offsite backup transport (see the NAS spec,
  # section 12). Folders live on the bind-mounted rpool-usb-1/syncthing
  # dataset; the state directory (/var/lib/syncthing) is bind-mounted from
  # host-persistent storage so the device identity survives container
  # recreation. Runs as ferrarimarco to keep dataset ownership aligned with
  # the host and Samba.
  #
  # The sync topology (devices, folders, and their sharing) is deliberately
  # NOT declared here: device IDs are private material (global discovery
  # resolves a device ID to its current public IP), so they never enter the
  # repository. The topology is configured once via the GUI/API and persists
  # in the state bind mount, like the GUI credentials and the Samba password
  # (NAS spec, section 12.4).
  services.syncthing = {
    enable = true;
    user = "ferrarimarco";
    group = "users";
    dataDir = "/var/lib/syncthing";
    # 22000/tcp+udp (transfers) and 21027/udp (local discovery).
    openDefaultPorts = true;
    # LAN-reachable GUI/API for administration and the blackbox probe.
    guiAddress = "0.0.0.0:8384";
    # Non-topology settings are merged on activation: declared keys are
    # enforced, keys left undeclared (like the imperative GUI credentials)
    # are preserved.
    settings = {
      options = {
        # Static-address connectivity over the tailnet only: no public
        # discovery, relays, or NAT traversal. This also avoids advertising
        # this device's addresses to the global discovery network.
        globalAnnounceEnabled = false;
        relaysEnabled = false;
        natEnabled = false;
        # Usage reporting declined.
        urAccepted = -1;
      };
      # HTTPS for the LAN-exposed GUI (self-signed certificate).
      gui.useTLS = true;
    };
  };

  # The Syncthing GUI/API port; openDefaultPorts covers the sync ports.
  networking.firewall.allowedTCPPorts = [ 8384 ];

  # Directory provisioning via systemd-tmpfiles. Because the Syncthing folder
  # objects are configured imperatively (device IDs are private material, see
  # above), nothing declarative would otherwise create their on-disk paths:
  # these rules keep the storage layout in the repository even though the
  # sync topology is not, and they run before the service starts, so the
  # one-time GUI configuration points at directories that already exist with
  # the right ownership instead of relying on Syncthing to create them.
  #
  # The /var/lib/syncthing rule serves two purposes: the service runs as an
  # unprivileged user that cannot create its own state directory under the
  # root-owned /var/lib, so without the rule the service only works where the
  # Proxmox bind mount already provides the directory (and fails, for
  # example, in the integration-test VM, which has no bind mounts); and on
  # the deployed container it enforces the owner-only mode on the mounted
  # host directory, which holds the device private key, matching the Ansible
  # declaration on pve1 so the two layers never fight over it.
  systemd.tmpfiles.rules = [
    "d /var/lib/syncthing 0700 ferrarimarco users -"
    "d /mnt/shared/syncthing/backup-inbound 0755 ferrarimarco users -"
    "d /mnt/shared/syncthing/media-outbound 0755 ferrarimarco users -"
  ];

  # Per-host shares backed by pve1's rpool-usb-1 pool. Each share is three
  # coupled declarations: the host dataset (Ansible), the bind mount
  # (Terraform), and this export (see the NAS spec, section 5.1).
  services.samba.settings = {
    "media-usb" = {
      "path" = "/mnt/shared/media-usb";
      "browseable" = "yes";
      "read only" = "no";
      "guest ok" = "no";
      "valid users" = "ferrarimarco";
    };
    "backups-usb" = {
      "path" = "/mnt/shared/backups-usb";
      "browseable" = "yes";
      "read only" = "no";
      "guest ok" = "no";
      "valid users" = "ferrarimarco";
    };
  };
}
