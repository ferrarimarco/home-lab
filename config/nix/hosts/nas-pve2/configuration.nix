_: {
  imports = [
    ../../roles/common
    ../../roles/nas
    ../../roles/comin
  ];

  # Required per-host value; a host may also add its own shares (see the NAS
  # spec, section 5.1).
  networking.hostName = "nas-pve2";
}
