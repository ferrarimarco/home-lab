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

      # Pin the release the bootstrap image was built against.
      system.stateVersion = "25.11";
    })
  ];

  lxcSystem = nixpkgs.lib.nixosSystem {
    inherit system;
    specialArgs = { inherit inputs bootstrapPublicKeys; };
    modules = lxcModules;
  };

  inherit (lxcSystem.config.system.build) tarball;

in
tarball
// {
  modules = lxcModules;
  inherit bootstrapPublicKeys;
}
