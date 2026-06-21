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

      # Load Public Keys: Support multiple keys (one per line), ignoring comments and empty lines
      hasPublicKey = builtins.pathExists homeLabBootstrapPublicKeyPath;
      bootstrapPublicKeys =
        if hasPublicKey then
          # Force evaluation of the guardrail before reading the public key.
          builtins.seq _guardrail (
            let
              lines = lib.strings.splitString "\n" (builtins.readFile homeLabBootstrapPublicKeyPath);
              cleanLines = map lib.strings.trim lines;
            in
            builtins.filter (line: line != "" && !lib.strings.hasPrefix "#" line) cleanLines
          )
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
        map (
          host:
          let
            hostDir = hostsDir + "/${host}";
            overrideFile = hostDir + "/test-override.nix";

            # Import the override file (could be a flat set OR a function)
            importedOverride = if builtins.pathExists overrideFile then import overrideFile else { };

            # Evaluate if importedOverride is a function, otherwise use it raw
            extraArgs =
              if builtins.isFunction importedOverride then
                importedOverride { inherit pkgs self lib; }
              else
                importedOverride;
          in
          {
            name = "host-${host}-test";
            value = import ./tests/make-test.nix (
              {
                inherit
                  pkgs
                  lib
                  inputs
                  bootstrapPublicKeys
                  ;
                hostConfiguration = hostDir + "/configuration.nix";
              }
              // extraArgs
            );
          }
        ) (builtins.filter (host: builtins.pathExists (hostsDir + "/${host}/configuration.nix")) hostNames)
      );

      dynamicNixosConfigurations = lib.listToAttrs (
        map (host: {
          name = host;
          value = nixpkgs.lib.nixosSystem {
            inherit system;
            specialArgs = { inherit inputs bootstrapPublicKeys; };
            modules = [
              (hostsDir + "/${host}/configuration.nix")
            ];
          };
        }) (builtins.filter (host: builtins.pathExists (hostsDir + "/${host}/configuration.nix")) hostNames)
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

      packages.${system} = {
        nixos-installer = import ./packages/nixos-installer.nix {
          inherit
            nixpkgs
            system
            inputs
            bootstrapPublicKeys
            ;
        };
      };

      formatter.${system} = treefmtEval.config.build.wrapper;

      checks.${system} = {
        lint-treefmt-nix = treefmtEval.config.build.check self;

        shell-devShell = self.devShells.${system}.default;
        shell-opsShell = self.devShells.${system}.operations;
      }
      // hostTests;

      nixosConfigurations = dynamicNixosConfigurations;
    };
}
