{ config, ... }:

{
  services.comin = {
    enable = true;

    repositorySubdir = "config/nix";

    # Prometheus exporter
    exporter = {
      openFirewall = true;
    };

    remotes = [
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

    hostname = config.networking.hostName;
  };
}
