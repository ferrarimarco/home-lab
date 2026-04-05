{
  description = "Home Lab Nix flake";

  inputs = {
    # Reference in case we want to switch to unstable
    # nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";

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

      # Use legacyPackages instead of packages to avoid evaluating unneeded
      # packages.
      # Ref: https://github.com/NixOS/nixpkgs/blob/1073dad219cb244572b74da2b20c7fe39cb3fa9e/flake.nix#L206
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };

      treefmtEval = treefmt-nix.lib.evalModule pkgs (import ./treefmt.nix { inherit pkgs; });
    in
    {
      devShells.${system} = {
        default = import ./shell.nix { inherit pkgs; };
        operations = import ./shell-operations.nix { inherit pkgs; };
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
