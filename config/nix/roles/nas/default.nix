{ lib, ... }:

{
  imports = [
    ../proxmox-lxc
  ];

  # Plain values override the proxmox-lxc role's lib.mkDefault defaults;
  # identical for every NAS container.
  proxmoxLXC = {
    # The container is made privileged by Terraform (`unprivileged = false`,
    # section 6.1) so bind-mounted ZFS datasets keep their host UID/GID
    # (host 1000 = container 1000) without an idmap. This option does NOT
    # control that: it only tells the NixOS guest module to expect a
    # privileged environment, and it must agree with the Terraform setting.
    privileged = true;

    # NAS hosts pin networking.hostName: comin selects the configuration by
    # hostname and asserts at build time that it is non-empty. Without this
    # override, the upstream proxmox-lxc module forces networking.hostName
    # to "" (expecting the PVE-written /etc/hostname to provide it), which
    # would fail that assertion. See the note on hostname in the framework
    # spec, section 3.
    manageHostName = true;
  };

  # Samba Server
  services.samba = {
    enable = lib.mkDefault true;
    openFirewall = lib.mkDefault true;

    settings = {
      global = {
        "workgroup" = lib.mkDefault "WORKGROUP";
        "server string" = lib.mkDefault "NixOS NAS";
        "security" = "user";
        "map to guest" = "never";

        # No performance tuning: modern Samba defaults already enable AIO
        # (aio read/write size = 1), and the once-popular tuning knobs
        # interact badly (e.g. a non-zero "aio write size" disables the
        # receivefile path that "min receivefile size" enables). Add tuning
        # only with a benchmark that justifies it.
      };

      # Shares. Every NAS container exposes the same in-container mount points;
      # each node's Terraform bind mounts map its own host datasets onto these
      # paths (see the NAS spec, section 6), so this role is identical across
      # nodes.
      "media" = {
        "path" = "/mnt/shared/media";
        "browseable" = "yes";
        "read only" = "no";
        "guest ok" = "no";
        "valid users" = "ferrarimarco";
      };
      "backups" = {
        "path" = "/mnt/shared/backups";
        "browseable" = "yes";
        "read only" = "no";
        "guest ok" = "no";
        "valid users" = "ferrarimarco";
      };
    };
  };
}
