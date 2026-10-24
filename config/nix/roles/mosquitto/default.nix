{ config, lib, ... }:

let
  mqttPort = 1883;
in
{
  # MQTT broker for the smart home workloads (Home Assistant, Frigate,
  # Zigbee2MQTT), reached over the plain MQTT port; see the MQTT broker
  # specification.
  services.mosquitto = {
    enable = lib.mkDefault true;

    # Persistence is on by default: retained messages and subscriptions
    # survive restarts in /var/lib/mosquitto (the module's dataDir). The
    # consumers republish their retained topics when they reconnect, so this
    # state is a cache, not something to back up.

    listeners = [
      {
        port = mqttPort;

        # Open listener, like the broker it replaces: the module writes a
        # password file and an ACL file for every listener, so open access
        # needs all three settings. The ACL rule is a pattern, not a topic
        # line: a topic line covers anonymous clients only, and a client that
        # presents a username (Home Assistant's entry may) would be denied
        # every topic. Authentication and TLS are tracked in the specs todo
        # list (Security): the module takes password files and certificates
        # from host paths, which needs a secret delivery path the NixOS hosts
        # do not have yet.
        omitPasswordAuth = true;
        settings.allow_anonymous = true;
        acl = [ "pattern readwrite #" ];
      }
    ];
  };

  # The module has no openFirewall option.
  networking.firewall.allowedTCPPorts = lib.mkIf config.services.mosquitto.enable [ mqttPort ];
}
