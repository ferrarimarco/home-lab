{ pkgs }:

pkgs.mkShell {
  packages = with pkgs; [
    gh
    jq
    nixos-anywhere
    nixos-rebuild
    terraform
  ];

  shellHook = ''
    echo "Nix Operations Shell Active" >&2
  '';
}
