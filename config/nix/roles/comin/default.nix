{ config, lib, ... }:

{
  services.comin = {
    enable = lib.mkDefault true;

    repositorySubdir = lib.mkDefault "config/nix";

    # Prometheus exporter
    exporter = {
      openFirewall = lib.mkDefault true;
    };

    remotes = lib.mkDefault [
      {
        name = "origin";
        url = "https://github.com/ferrarimarco/home-lab.git";

        branches = {
          main = {
            name = "master";
          };
        };
      }
    ];

    hostname = lib.mkDefault config.networking.hostName;
  };
}
