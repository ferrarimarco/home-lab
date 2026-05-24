{ pkgs }:

pkgs.mkShell {
  packages = with pkgs; [
    nixos-anywhere
    terraform
  ];

  shellHook = ''
    echo "Nix Operations Shell Active"
  '';
}
