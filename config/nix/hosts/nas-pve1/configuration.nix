_: {
  imports = [
    ../../roles/common
    ../../roles/nas
    ../../roles/comin
  ];

  # Required per-host value; a host may also add its own shares (see the NAS
  # spec, section 5.1).
  networking.hostName = "nas-pve1";

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
