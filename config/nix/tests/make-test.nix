{
  pkgs,
  lib,
  inputs,
  hostConfiguration,
  extraConfig ? { },
  extraTestScript ? "",
  ...
}@args:

let
  # Strip out the test-harness arguments so we can pass everything else down
  passedArgs = builtins.removeAttrs args [
    "pkgs"
    "lib"
    "inputs"
    "hostConfiguration"
    "extraConfig"
    "extraTestScript"
  ];

  # Combine default fallback mocks with whatever your flake explicitly passes
  nodeArgs = {
    inputs = { };
    self = { };
  }
  // passedArgs;

  eval = pkgs.testers.nixosTest {
    name = "eval-host-name";
    nodes.machine = {
      _module.args = nodeArgs // {
        inherit inputs;
      };
      imports = [
        inputs.comin.nixosModules.comin
        hostConfiguration
      ];
      networking.hostName = lib.mkDefault "unnamed-host";
    };
    testScript = "";
  };

  mockRepoPath = "/tmp/mock-upstream-repo";

  inherit (eval.nodes.machine.networking) hostName;
in
pkgs.testers.nixosTest {
  name = "${hostName}-test";

  nodes.machine =
    { config, ... }:
    {
      _module.args = nodeArgs // {
        inherit inputs;
      };

      imports = [
        inputs.comin.nixosModules.comin
        hostConfiguration
        extraConfig
      ];

      # Ensure the test runs in a predictable environment
      # Sometimes modules might try to override the hostname; forcing it ensures
      # the test derivation name and the internal OS state remain synced.
      networking.hostName = lib.mkForce hostName;

      # Dynamic VM hardware setup:
      # If the guest agent is enabled in the NixOS config, automatically
      # provision the virtual serial port hardware in QEMU.
      virtualisation.qemu.options = lib.mkIf config.services.qemuGuest.enable [
        "-device virtio-serial"
        "-device virtserialport,chardev=qga0,name=org.qemu.guest_agent.0"
        "-chardev null,id=qga0"
      ];

      # If the host imports the comin role, divert its target to look at the
      # sandbox's local file system instead of a remote repository.
      services.comin.remotes = lib.mkIf config.services.comin.enable (
        lib.mkVMOverride [
          {
            name = "origin";
            url = "file://${mockRepoPath}";
            # Shorten the poll interval so we don't trigger the test timeout
            poller.period = 2;
          }
        ]
      );
    };

  # Dynamic test script generation:
  # Inspects the evaluated system configuration and appends Python
  # assertions dynamically based on active services.
  testScript =
    { nodes, ... }:
    let
      node_config = nodes.machine;

      # Verify SSH port if openssh service is enabled
      sshCheck = lib.optionalString node_config.services.openssh.enable ''
        machine.wait_for_open_port(22)
      '';

      # Verify QEMU guest agent if guest agent service is enabled
      qemuAgentCheck = lib.optionalString node_config.services.qemuGuest.enable ''
        machine.wait_for_file("/dev/virtio-ports/org.qemu.guest_agent.0")
        machine.wait_for_unit("qemu-guest-agent.service")
      '';

      cominCheck = lib.optionalString node_config.services.comin.enable ''
        print("--- GitOps Phase 1: Mocking Local Git Repository Layout ---")
        machine.succeed(
            "mkdir -p ${mockRepoPath}/config/nix",
            "cd ${mockRepoPath} && git init",
            "git config --global user.email 'test@${hostName}.local'",
            "git config --global user.name 'Test Runner'",

            # ❄️ Create a minimal valid flake.nix that comin can evaluate
            "cat << 'EOF' > ${mockRepoPath}/config/nix/flake.nix\n"
            "{\n"
            "  inputs.nixpkgs.url = \"path:${pkgs.path}\";\n"
            "  outputs = { self, nixpkgs, ... }:\n"
            "    {\n"
            "      nixosConfigurations.${hostName} = nixpkgs.lib.nixosSystem {\n"
            "        system = \"x86_64-linux\";\n"
            "        modules = [ ({ modulesPath, ... }: { \n"
            "          boot.loader.grub.enable = false;\n"
            "          fileSystems.\"/\" = { device = \"/dev/placeholder\"; };\n"
            "        }) ];\n"
            "        };\n"
            "    };\n"
            "}\n"
            "EOF",

            "echo '# Baseline' > ${mockRepoPath}/config/nix/dummy.nix",
            "cd ${mockRepoPath} && git add . && git commit -m 'initial production commit'",
            "cd ${mockRepoPath} && git checkout -b main"
        )

        print("--- GitOps Phase 2: Verifying Comin Agent Startup ---")
        machine.start_job("comin.service")
        machine.wait_for_unit("comin.service")

        print("--- GitOps Phase 3: Simulating push to testing-${hostName} ---")
        machine.succeed(
            "cd ${mockRepoPath} && git checkout -b testing-${hostName}",
            "echo '# Staged Change' >> ${mockRepoPath}/config/nix/dummy.nix",
            "cd ${mockRepoPath} && git add . && git commit -m 'test: pull-based staging update'"
        )

        print("--- GitOps Phase 4: Forcing Immediate Comin Execution Sync ---")
        machine.succeed("systemctl restart comin.service")
        machine.wait_until_succeeds("journalctl -u comin.service | grep -q 'scheduler: starting the period job'", timeout=30)
        machine.wait_until_succeeds("journalctl -u comin.service | grep -q 'New commits have been fetched'", timeout=30)
        machine.wait_until_succeeds("journalctl -u comin.service | grep -q 'a generation is evaluating'", timeout=30)

        print("--- GitOps Phase 5: Verifying Prometheus Metrics Exporter ---")

        # Wait for the HTTP server socket to be active and serving text
        machine.wait_for_open_port(4243)

        print("Scraping raw metrics endpoint:")
        print(machine.succeed("curl -v http://localhost:4243/metrics"))

        # Scrape the endpoint and ensure it contains valid metrics data
        machine.succeed("curl -sSf http://localhost:4243/metrics | grep -q 'comin_fetch_count'")
        print("Prometheus metrics endpoint verified successfully!")
      '';
    in
    ''
      # Boot check (common to all hosts)
      machine.wait_for_unit("multi-user.target")

      # Every host (including mock fixtures) will evaluate these rules

      # Verify hostname configuration
      current_hostname = machine.succeed("hostname").strip()
      assert current_hostname == "${hostName}", f"Host routing divergence! Expected kernel hostname '${hostName}', but got: {current_hostname}"

      # Dynamic service assertions
      ${sshCheck}
      ${qemuAgentCheck}
      ${cominCheck}

      # Host-specific custom assertions (if any)
      ${extraTestScript}
    '';
}
