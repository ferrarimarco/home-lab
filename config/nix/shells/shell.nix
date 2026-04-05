{ pkgs }:

pkgs.mkShell {
  packages = with pkgs; [
    deadnix
    nixd
    nixfmt
    statix
  ];

  shellHook = ''
    echo "Nix Dev Shell Active"
  '';
}
