_: {
  # Used to find the project root
  projectRootFile = "flake.nix";

  programs = {
    deadnix.enable = true;
    nixfmt.enable = true;
    statix.enable = true;
  };
}
