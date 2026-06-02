{
  nixpkgs,
  system,
  inputs,
  bootstrapPublicKeys,
}:

let
  installerSystem = nixpkgs.lib.nixosSystem {
    inherit system;
    specialArgs = { inherit inputs bootstrapPublicKeys; };
    modules = [
      (
        { modulesPath, lib, ... }:
        {
          imports = [
            "${modulesPath}/installer/cd-dvd/installation-cd-minimal.nix"
          ];

          # Force SSH daemon to spin up instantly at boot for headless provisioning
          systemd.services.sshd.wantedBy = lib.mkForce [ "multi-user.target" ];
        }
      )

      ../roles/proxmox-vm
      (_: {
        users.users.root.openssh.authorizedKeys.keys = bootstrapPublicKeys;
      })
    ];
  };
in
installerSystem.config.system.build.isoImage
