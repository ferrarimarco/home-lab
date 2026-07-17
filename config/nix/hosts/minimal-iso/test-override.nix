{ pkgs, self, ... }:

let
  inherit (pkgs.stdenv.hostPlatform) system;
  installerIso = self.packages.${system}.nixos-installer;
in
{
  extraConfig = {
    imports = installerIso.modules;
    virtualisation.memorySize = 2048;
    virtualisation.graphics = false;
  };
}
