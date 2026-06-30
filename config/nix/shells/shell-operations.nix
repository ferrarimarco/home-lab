{ pkgs }:

pkgs.mkShell {
  packages = with pkgs; [
    jq
    nixos-anywhere
    nixos-rebuild
    terraform
  ];

  shellHook = ''
    echo "Nix Operations Shell Active"
  '';
}
