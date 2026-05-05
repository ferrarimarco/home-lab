{ pkgs, ... }:

{
  boot.supportedFilesystems = [ "zfs" ];

  # ZFS maintenance
  services.zfs.autoScrub.enable = true;

  environment.systemPackages = with pkgs; [
    zfs
  ];
}
