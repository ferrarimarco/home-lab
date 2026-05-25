{
  nixos-generators,
  system,
  inputs,
  bootstrapPublicKey,
}:

nixos-generators.nixosGenerate {
  inherit system;
  format = "install-iso";
  specialArgs = { inherit inputs bootstrapPublicKey; };
  modules = [
    ../roles/proxmox-vm
    (_: {
      users.users.root.openssh.authorizedKeys.keys = [ bootstrapPublicKey ];
    })
  ];
}
