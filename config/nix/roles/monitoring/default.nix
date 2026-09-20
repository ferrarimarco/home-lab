{ lib, ... }:

{
  services.prometheus.exporters.node = {
    enable = lib.mkDefault true;
    openFirewall = lib.mkDefault true;
  };
}
