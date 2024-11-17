{ pkgs }:
{
  # Used to find the project root
  projectRootFile = "flake.nix";

  programs = {
    deadnix.enable = true;
    statix.enable = true;

    nixfmt = {
      enable = true;
      package = pkgs.nixfmt;
    };
  };
}
