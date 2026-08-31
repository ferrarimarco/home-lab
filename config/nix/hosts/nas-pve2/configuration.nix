_: {
  imports = [
    ../../roles/common
    ../../roles/nas
    ../../roles/comin
  ];

  # Required per-host value; a host may also add its own shares (see the NAS
  # spec, section 5.1).
  networking.hostName = "nas-pve2";

  # Per-host shares backed by pve2's scratch pools. Each share is three
  # coupled declarations: the host dataset (Ansible), the bind mount
  # (Terraform), and this export (see the NAS spec, section 5.1).
  services.samba.settings = {
    "scratch-hdd" = {
      "path" = "/mnt/shared/scratch-hdd";
      "browseable" = "yes";
      "read only" = "no";
      "guest ok" = "no";
      "valid users" = "ferrarimarco";
    };
    "scratch-ssd" = {
      "path" = "/mnt/shared/scratch-ssd";
      "browseable" = "yes";
      "read only" = "no";
      "guest ok" = "no";
      "valid users" = "ferrarimarco";
    };
  };
}
