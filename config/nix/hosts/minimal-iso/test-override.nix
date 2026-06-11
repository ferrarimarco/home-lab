{ pkgs, self, ... }:

let
  inherit (pkgs.stdenv.hostPlatform) system;
  installerIso = self.packages.${system}.nixos-installer;
in
{
  extraConfig = {
    imports = installerIso.modules;
    virtualisation.memorySize = 2048;
    virtualisation.graphics = false;
  };

  extraTestScript =
    let
      joinedKeys = pkgs.lib.concatStringsSep "\n" installerIso.bootstrapPublicKeys;
    in
    ''
      print("--- Phase 1: Reading Authorized Keys from Root Account ---")

      actual_keys = machine.succeed("cat /etc/ssh/authorized_keys.d/root").strip()

      print("--- Phase 2: Verifying Presence of Bootstrap Public Keys ---")
      expected_keys = """
      ${joinedKeys}
      """.strip()

      # Iterate through and verify each key specified in bootstrapPublicKeys
      for key in expected_keys.splitlines():
          trimmed_key = key.strip()
          if not trimmed_key:
              continue

          print(f"Checking for key: {trimmed_key[:30]}...")
          if trimmed_key in actual_keys:
              print("→ Key verified in target environment!")
          else:
              raise Exception(f"Security assertion failed: Expected bootstrap key was missing from the system!\nMissing key: {trimmed_key}")
    '';
}
