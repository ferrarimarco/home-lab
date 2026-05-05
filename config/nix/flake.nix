{
  description = "Home Lab Nix flake";

  inputs = {
    # Reference in case we want to switch to unstable
    # nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";

    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";

    treefmt-nix.url = "github:numtide/treefmt-nix";
    treefmt-nix.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    {
      self,
      nixpkgs,
      treefmt-nix,
      ...
    }@inputs:
    let
      system = "x86_64-linux";

      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };

      inherit (nixpkgs) lib;

      treefmtEval = treefmt-nix.lib.evalModule pkgs ./treefmt.nix;

      # Auto-discover host integration tests
      hostsDir = ./hosts;
      hostNames = builtins.attrNames (
        lib.filterAttrs (_name: type: type == "directory") (builtins.readDir hostsDir)
      );
      hostTests = lib.listToAttrs (
        map (host: {
          name = "${host}-test";
          value = import (hostsDir + "/${host}/test.nix") { inherit pkgs; };
        }) (builtins.filter (host: builtins.pathExists (hostsDir + "/${host}/test.nix")) hostNames)
      );
    in
    {
      devShells.${system} = {
        default = import ./shells/shell.nix { inherit pkgs; };
        operations = import ./shells/shell-operations.nix { inherit pkgs; };
      };

      formatter.${system} = treefmtEval.config.build.wrapper;

      checks.${system} = {
        treefmt-nix = treefmtEval.config.build.check self;

        devShell = self.devShells.${system}.default;
        opsShell = self.devShells.${system}.operations;
      }
      // hostTests;

      nixosConfigurations = {
        hl02 = nixpkgs.lib.nixosSystem {
          inherit system;

          specialArgs = { inherit inputs; };

          modules = [
            ./hosts/hl02/default.nix
          ];
        };
      };
    };
}
