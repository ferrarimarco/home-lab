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

    comin = {
      url = "github:nlewo/comin";
      inputs.nixpkgs.follows = "nixpkgs";
    };
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

      sshKeysDir = ../ansible/playbooks/files/ssh;
      homeLabBootstrapPublicKeyPath = sshKeysDir + "/home-lab-node-ssh-key.pub";

      hasPublicKey = builtins.pathExists homeLabBootstrapPublicKeyPath;
      bootstrapPublicKeys =
        if hasPublicKey then
          (
            let
              # Load Public Keys: Support multiple keys (one per line), ignoring comments and empty lines
              lines = lib.strings.splitString "\n" (builtins.readFile homeLabBootstrapPublicKeyPath);
              cleanLines = map lib.strings.trim lines;
            in
            builtins.filter (line: line != "" && !lib.strings.hasPrefix "#" line) cleanLines
          )
        else
          throw "ERROR: Public bootstrap key is missing at '${toString homeLabBootstrapPublicKeyPath}'.";

      treefmtEval = treefmt-nix.lib.evalModule pkgs ./treefmt.nix;

      # Automatically discover and register integration tests for all hosts.
      #
      # Mechanism:
      # 1. Scan the ./hosts directory for subdirectories (each representing a host).
      # 2. Keep the ones containing a 'default.nix' file (the same marker that
      #    registers the host in nixosConfigurations below).
      # 3. For each host, compose its 'configuration.nix' with the optional
      #    'test-override.nix' via tests/make-test.nix and register the result as a
      #    check attribute: { name = "host-<host>-test"; value = <test-derivation>; }.
      # 4. Convert the list of attributes into a set and merge it into flake 'checks'.
      #
      # This makes the test suite zero-maintenance: adding a new host directory with
      # a 'default.nix' automatically includes it in 'nix flake check' and CI.
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
        ) (builtins.filter (host: builtins.pathExists (hostsDir + "/${host}/default.nix")) hostNames)
      );

      dynamicNixosConfigurations = lib.listToAttrs (
        map (host: {
          name = host;
          value = nixpkgs.lib.nixosSystem {
            inherit system;
            specialArgs = { inherit inputs bootstrapPublicKeys; };
            modules = [
              inputs.comin.nixosModules.comin
              (hostsDir + "/${host}/default.nix")
            ];
          };
        }) (builtins.filter (host: builtins.pathExists (hostsDir + "/${host}/default.nix")) hostNames)
      );

    in

    {
      devShells.${system} = {
        default = import ./shells/shell.nix { inherit pkgs; };
        operations = import ./shells/shell-operations.nix { inherit pkgs; };
      };

      packages.${system} =
        let
          nixos-installer = import ./packages/nixos-installer.nix {
            inherit
              nixpkgs
              system
              inputs
              bootstrapPublicKeys
              ;
          };
          nixos-lxc-bootstrap = import ./packages/lxc-bootstrap.nix {
            inherit
              nixpkgs
              system
              inputs
              bootstrapPublicKeys
              ;
          };
        in
        {
          inherit nixos-installer nixos-lxc-bootstrap;

          # Stages the image artifacts Terraform reads behind a single
          # `result` symlink (result/iso and result/tarball), so the ISO and
          # the LXC template coexist. See the proxmox-lxc spec, section 5.4.
          proxmox-images = import ./packages/proxmox-images.nix {
            inherit pkgs;
            nixosInstaller = nixos-installer;
            nixosLxcBootstrap = nixos-lxc-bootstrap;
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
