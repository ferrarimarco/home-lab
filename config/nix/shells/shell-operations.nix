{ pkgs }:

pkgs.mkShell {
  packages = with pkgs; [
    jq
    nixos-anywhere
    terraform
  ];

  shellHook = ''
    echo "Nix Operations Shell Active"
  '';
}
