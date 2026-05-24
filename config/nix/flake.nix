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

      # --- Security Guardrail & Key Loading ---
      sshKeysDir = ./ssh-keys;
      homeLabBootstrapPrivateKeyPath = sshKeysDir + "/home-lab-bootstrap-ssh";
      homeLabBootstrapPublicKeyPath = sshKeysDir + "/home-lab-bootstrap-ssh.pub";

      # Guardrail: Abort if private key is tracked in Git (exists in Nix store).
      # Nix Flakes in pure evaluation mode exclude untracked files from the sandboxed
      # Nix store. If this file exists in the store, it means it has been tracked
      # or staged in Git, which is a critical security risk.
      hasPrivateKey = builtins.pathExists homeLabBootstrapPrivateKeyPath;
      _guardrail =
        if hasPrivateKey then
          throw "CRITICAL SECURITY ERROR: Private key '${toString homeLabBootstrapPrivateKeyPath}' is tracked in Git! Remove it from Git immediately."
        else
          true;

      # Load Public Key: Abort if public key is missing
      hasPublicKey = builtins.pathExists homeLabBootstrapPublicKeyPath;
      bootstrapPublicKey =
        if hasPublicKey then
          # Force evaluation of the guardrail before reading the public key.
          builtins.seq _guardrail (lib.strings.trim (builtins.readFile homeLabBootstrapPublicKeyPath))
        else
          throw "ERROR: Public bootstrap key is missing at '${toString homeLabBootstrapPublicKeyPath}'.";
      # ----------------------------------------

      treefmtEval = treefmt-nix.lib.evalModule pkgs ./treefmt.nix;

      # Automatically discover and register integration tests for all hosts.
      #
      # Mechanism:
      # 1. Scan the ./hosts directory for subdirectories (each representing a host).
      # 2. Filter out directories that do not contain a 'test.nix' file.
      # 3. For each valid host, import its 'test.nix' and format it as a check
      #    attribute: { name = "<hostname>-test"; value = <test-derivation>; }.
      # 4. Convert the list of attributes into a set and merge it into flake 'checks'.
      #
      # This makes the test suite zero-maintenance: adding a new host with a 'test.nix'
      # will automatically include it in 'nix flake check' and CI without modifications here.
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
    # Force evaluation of the security guardrail. Because Nix is lazy, the
    # _guardrail check would be completely ignored unless we force its evaluation
    # by sequencing it before the returned flake output attribute set.
    builtins.seq _guardrail {
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

          specialArgs = { inherit inputs bootstrapPublicKey; };

          modules = [
            ./hosts/hl02/default.nix
          ];
        };
      };
    };
}
