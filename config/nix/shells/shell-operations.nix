{ pkgs }:

pkgs.mkShell {
  packages = with pkgs; [
    terraform
  ];

  shellHook = ''
    echo "Nix Operations Shell Active"
  '';
}
