{ pkgs }:

pkgs.mkShell {
  packages = with pkgs; [
    deadnix
    nixd
    nixfmt
    terraform
    statix
  ];

  shellHook = ''
    echo "❄️ Nix Dev Shell Active"
  '';
}
