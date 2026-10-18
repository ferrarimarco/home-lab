{ pkgs }:

pkgs.mkShell {
  packages = with pkgs; [
    gh
    ipmitool
    jq
    nixos-anywhere
    nixos-rebuild
    terraform
  ];

  shellHook = ''
    echo "Nix Operations Shell Active" >&2
  '';
}
