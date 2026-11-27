{ lib, ... }:

{
  services.prometheus.exporters.node = {
    enable = lib.mkDefault true;
    openFirewall = lib.mkDefault true;
    # The unit alerts (failed, restart-looping, and the per-service rules)
    # read node_systemd_unit_state, which only this collector exports.
    enabledCollectors = [ "systemd" ];
    # The restart-frequency alert reads the count of automatic restarts,
    # which the collector leaves out unless asked.
    extraFlags = [ "--collector.systemd.enable-restarts-metrics" ];
  };
}
