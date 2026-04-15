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

      treefmtEval = treefmt-nix.lib.evalModule pkgs ./treefmt.nix;
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
      };

      nixosConfigurations = {
        nas1 = nixpkgs.lib.nixosSystem {
          inherit system;

          specialArgs = { inherit inputs; };

          modules = [
            ./hosts/nas1/default.nix
          ];
        };
      };
    };
}
