{
  nixpkgs,
  system,
  inputs,
  bootstrapPublicKeys,
}:

let
  lxcModules = [
    ../roles/proxmox-lxc

    (_: {
      users.users.root.openssh.authorizedKeys.keys = bootstrapPublicKeys;
    })
  ];

  lxcSystem = nixpkgs.lib.nixosSystem {
    inherit system;
    specialArgs = { inherit inputs bootstrapPublicKeys; };
    modules = lxcModules;
  };

in
lxcSystem.config.system.build.tarball
