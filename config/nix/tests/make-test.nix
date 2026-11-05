{
  pkgs,
  lib,
  inputs,
  hostConfiguration,
  bootstrapPublicKeys ? [ ],
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
    "bootstrapPublicKeys"
    "extraConfig"
    "extraTestScript"
  ];

  # Combine default fallback mocks with whatever your flake explicitly passes
  nodeArgs = {
    inputs = { };
    self = { };
  }
  // passedArgs
  // {
    inherit bootstrapPublicKeys;
  };

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
    { config, options, ... }:
    {
      # imports must live at the absolute top-level of the module
      imports = [
        inputs.comin.nixosModules.comin
        hostConfiguration
        extraConfig
      ];

      # All actual option assignments go inside 'config' so they can be merged conditionally
      config = lib.mkMerge [
        # --- Unconditional Settings (Always applied) ---
        {
          _module.args = nodeArgs // {
            inherit inputs;
          };

          # Dynamic VM hardware setup:
          # If the guest agent is enabled in the NixOS config, automatically
          # provision the virtual serial port hardware in QEMU.
          virtualisation.qemu.options = lib.mkIf config.services.qemuGuest.enable [
            "-device virtio-serial"
            "-device virtserialport,chardev=qga0,name=org.qemu.guest_agent.0"
            "-chardev null,id=qga0"
          ];

          # Ensure the test runs in a predictable environment
          # Sometimes modules might try to override the hostname; forcing it ensures
          # the test derivation name and the internal OS state remain synced.
          networking.hostName = lib.mkVMOverride hostName;

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
        }

        # --- Samba Compatibility Settings ---
        # If the host serves Samba shares, create every declared share path as
        # a mock directory: the production paths are bind mounts (e.g. Proxmox
        # LXC mount points) that do not exist in the test sandbox.
        {
          systemd.tmpfiles.rules = lib.mkIf config.services.samba.enable (
            lib.mapAttrsToList (_: section: "d ${section.path} 0755 root root -") (
              lib.filterAttrs (_: section: section ? path) (
                builtins.removeAttrs config.services.samba.settings [ "global" ]
              )
            )
          );
        }

        # --- MQTT Broker Test Tooling ---
        # If the host runs the Mosquitto broker, ship the client tools the
        # round-trip assertion below uses; the broker package carries them.
        {
          environment.systemPackages = lib.mkIf config.services.mosquitto.enable [
            config.services.mosquitto.package
          ];
        }

        # --- Network Boot Server Test Tooling ---
        # If the host runs the boot server, ship the NFS client tools the
        # export assertions below use (showmount, mount.nfs) and a YAML parser
        # for the hand-rendered seed.
        (lib.optionalAttrs (options ? homeLab) {
          environment.systemPackages = lib.mkIf config.homeLab.netboot.enable [
            pkgs.nfs-utils
            (pkgs.python3.withPackages (ps: [ ps.pyyaml ]))
          ];
        })

        # --- LXC Compatibility Settings ---
        # If this is an LXC container (indicated by the presence of root-level proxmoxLXC options),
        # apply container-to-VM compatibility overrides so the QEMU VM test runner can boot it.
        (lib.optionalAttrs (options ? proxmoxLXC) {
          # Allow Nix to manage the hostname during tests if the LXC module is active
          proxmoxLXC.manageHostName = lib.mkVMOverride true;

          boot.isContainer = lib.mkVMOverride false;
          boot.loader.initScript.enable = lib.mkVMOverride false;
          boot.kernel.enable = lib.mkVMOverride true;
          boot.modprobeConfig.enable = lib.mkVMOverride true;
          services.udev.enable = lib.mkVMOverride true;

          fileSystems."/" = lib.mkVMOverride {
            device = "/dev/root";
            fsType = "ext4";
          };
        })
      ];
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

      # Hosts that are expected to have the bootstrap SSH key configured for the root user
      isBootstrapHost = lib.elem hostName [
        "nixos"
        "nixos-lxc"
      ];

      bootstrapKeyCheck = lib.optionalString (isBootstrapHost && bootstrapPublicKeys != [ ]) (
        let
          joinedKeys = pkgs.lib.concatStringsSep "\n" bootstrapPublicKeys;
        in
        ''
          print("--- Verifying Bootstrap Public Keys ---")
          actual_keys = machine.succeed("cat /etc/ssh/authorized_keys.d/root").strip()
          expected_keys = """
          ${joinedKeys}
          """.strip()

          for key in expected_keys.splitlines():
              trimmed_key = key.strip()
              if not trimmed_key:
                  continue

              print(f"Checking for bootstrap key: {trimmed_key[:30]}...")
              if trimmed_key in actual_keys:
                  print("→ Key verified in system environment!")
              else:
                  raise Exception(f"Security assertion failed: Expected bootstrap key missing from target node!\nMissing key: {trimmed_key}")
        ''
      );

      # Verify that passwordless sudo works for our administrative user account
      sudoCheck = lib.optionalString (builtins.hasAttr "ferrarimarco" node_config.users.users) ''
        print("--- Testing Passwordless Sudo ---")

        # Drop down to an unprivileged user shell and try to run a command with sudo.
        output = machine.succeed("su - ferrarimarco -c 'sudo whoami'").strip()

        assert output == "root", f"Sudo execution returned user '{output}' instead of elevating to 'root'!"
        print("Passwordless sudo verified successfully for user: ferrarimarco")
      '';

      # Verify QEMU guest agent if guest agent service is enabled
      qemuAgentCheck = lib.optionalString node_config.services.qemuGuest.enable ''
        machine.wait_for_file("/dev/virtio-ports/org.qemu.guest_agent.0")
        machine.wait_for_unit("qemu-guest-agent.service")
      '';

      # Verify the Prometheus node exporter if it is enabled. The port is
      # derived from the evaluated configuration, and the assertion targets
      # the metric name prefix so it does not depend on specific collectors.
      nodeExporterPort = toString node_config.services.prometheus.exporters.node.port;
      nodeExporterCheck = lib.optionalString node_config.services.prometheus.exporters.node.enable ''
        print("--- Verifying Prometheus Node Exporter ---")
        machine.wait_for_unit("prometheus-node-exporter.service")
        machine.wait_for_open_port(${nodeExporterPort})
        # grep reads the full stream (no -q early exit): quitting at the first
        # match closes the pipe while curl is still writing the large metrics
        # payload, failing the pipeline with curl's write error under pipefail.
        machine.succeed("curl -sSf http://localhost:${nodeExporterPort}/metrics | grep '^node_' > /dev/null")
        print("Node exporter metrics endpoint verified successfully!")
      '';

      # Verify Samba shares if the samba service is enabled. The share list is
      # derived from the evaluated configuration: every settings section
      # (besides global) that declares a path is expected to be exported.
      sambaShareNames = lib.attrNames (
        lib.filterAttrs (_: section: section ? path) (
          builtins.removeAttrs node_config.services.samba.settings [ "global" ]
        )
      );
      sambaCheck = lib.optionalString node_config.services.samba.enable ''
        machine.wait_for_unit("samba-smbd.service")
        # Anonymous (-N) share enumeration over the null session; this checks
        # that the shares are exported, not the authenticated access path,
        # since Samba passwords cannot be set declaratively. Each assertion
        # retries with a bounded timeout: the unit reporting active does not
        # guarantee smbd is accepting connections, and under boot load (for
        # example Syncthing on nas-pve1) early enumerations intermittently
        # fail or return incomplete listings. The consumer reads the full
        # stream (no `grep -q`): the driver runs commands under pipefail, and
        # an early-exiting consumer closes the pipe while smbclient is still
        # writing, failing the pipeline on EPIPE despite a successful match.
        ${lib.concatMapStringsSep "\n" (
          share:
          ''machine.wait_until_succeeds("smbclient -L localhost -N | grep '${share}' > /dev/null", timeout=120)''
        ) sambaShareNames}
      '';

      # Verify the Mosquitto broker if it enables at least one TCP listener
      # (a port of 0 is a Unix socket listener): every TCP listener port
      # opens, and retained messages published to the first one, by an
      # anonymous client and by a client presenting a username, come back to
      # fresh subscribers after a broker restart. The restart is what makes
      # this a persistence check: retained messages are served from the
      # in-memory database, which reaches the store the restart reloads at
      # shutdown, every autosave_interval (30 minutes by default), and on
      # SIGUSR1, so within the test only the shutdown write lands.
      # The named client proves the ACL admits clients with a username, which
      # a topic rule would not. The publishers and subscribers retry with a
      # bounded timeout: the unit reporting active does not guarantee the
      # broker accepts clients.
      mosquittoListenerPorts = map (listener: toString listener.port) (
        builtins.filter (listener: listener.port != 0) node_config.services.mosquitto.listeners
      );
      mosquittoFirstPort = builtins.head mosquittoListenerPorts;
      mosquittoCheck =
        lib.optionalString (node_config.services.mosquitto.enable && mosquittoListenerPorts != [ ])
          ''
            print("--- Verifying Mosquitto MQTT Broker ---")
            machine.wait_for_unit("mosquitto.service")
            ${lib.concatMapStringsSep "\n" (port: "machine.wait_for_open_port(${port})") mosquittoListenerPorts}
            machine.wait_until_succeeds("mosquitto_pub -h localhost -p ${mosquittoFirstPort} -t test/roundtrip/anonymous -m ok -r", timeout=60)
            machine.succeed("mosquitto_pub -h localhost -p ${mosquittoFirstPort} -u probe -t test/roundtrip/named -m ok -r")
            machine.systemctl("restart mosquitto.service")
            machine.wait_for_unit("mosquitto.service")
            machine.wait_for_open_port(${mosquittoFirstPort})
            for topic, user_flag in (("test/roundtrip/anonymous", ""), ("test/roundtrip/named", "-u probe")):
                received = machine.wait_until_succeeds(f"mosquitto_sub -h localhost -p ${mosquittoFirstPort} {user_flag} -t {topic} -C 1 -W 30", timeout=60).strip()
                assert received == "ok", f"Expected the retained message 'ok' on {topic} after the restart, got: {received!r}"
            print("MQTT retained round trips verified across a broker restart!")
          '';

      # Verify the network boot server if the host declares netboot hosts: the
      # payload unit unpacks its (mock) image, nothing is published while a
      # host's toggle is stopped, starting the toggle publishes the boot files
      # over TFTP, exports the host's root over NFSv3 (mounted back from the
      # server's own address to prove the export, not just its listing) with
      # the fstab rewritten, and serves the cloud-init seed over HTTP, which
      # parses as YAML; stopping withdraws the TFTP directory at once, keeps
      # the export listed, and removes it after the grace period. The TFTP and HTTP fetches go through the server address,
      # which the hl02 override points at the VM's test interface. The DHCP
      # proxy cannot be exercised without a PXE-class client; its presence is
      # read from the dnsmasq log.
      netboot = lib.attrByPath [ "homeLab" "netboot" ] { enable = false; } node_config;
      netbootHosts = lib.attrNames netboot.hosts;
      netbootPayloads = lib.unique (lib.mapAttrsToList (_: host: host.payload) netboot.hosts);
      netbootCheck = lib.optionalString (netboot.enable && netbootHosts != [ ]) ''
        print("--- Verifying the network boot server ---")
        for unit in ("dnsmasq.service", "nfs-server.service", "nginx.service"):
            machine.wait_for_unit(unit)
        machine.wait_until_succeeds("journalctl -u dnsmasq.service | grep 'proxy on subnet' > /dev/null", timeout=60)
        ${lib.concatMapStringsSep "\n" (payload: ''
          machine.wait_until_succeeds("test -f /var/lib/netboot/images/${payload}.pin", timeout=300)
          machine.succeed("test -d /var/lib/netboot/payloads/${payload}/boot && test -d /var/lib/netboot/payloads/${payload}/root/etc")
        '') netbootPayloads}
        ${lib.concatMapStringsSep "\n" (host: ''
          print("--- Rescue toggle of ${host} ---")
          machine.fail("curl -sSf tftp://${netboot.serverAddress}/${host}/config.txt > /dev/null")
          exports = machine.succeed("showmount -e localhost")
          assert "/var/lib/netboot/nfs/${host}" not in exports, f"Export of ${host} listed before its toggle started: {exports!r}"
          machine.succeed("systemctl start netboot-rescue@${host}.service")
          cmdline = machine.succeed("curl -sSf tftp://${netboot.serverAddress}/${host}/cmdline.txt")
          assert "nfsroot=${netboot.serverAddress}:/var/lib/netboot/nfs/${host}" in cmdline, f"Unexpected command line for ${host}: {cmdline!r}"
          machine.succeed("curl -sSf tftp://${netboot.serverAddress}/${host}/start4.elf > /dev/null")
          machine.fail("curl -sSf tftp://${netboot.serverAddress}/${host}/user-data > /dev/null")
          machine.succeed("showmount -e localhost | grep '/var/lib/netboot/nfs/${host}' > /dev/null")
          machine.succeed("mkdir -p /mnt/${host} && mount -t nfs -o vers=3,tcp,nolock ${netboot.serverAddress}:/var/lib/netboot/nfs/${host} /mnt/${host}")
          fstab = machine.succeed("cat /mnt/${host}/etc/fstab").strip()
          assert fstab == "proc /proc proc defaults 0 0", f"Unexpected fstab in the export of ${host}: {fstab!r}"
          machine.succeed("umount /mnt/${host}")
          seed = machine.succeed("curl -sSf http://${netboot.serverAddress}/seeds/${host}/user-data")
          assert seed.startswith("#cloud-config") and "hostname: ${host}" in seed, f"Unexpected rescue seed for ${host}: {seed[:200]!r}"
          machine.succeed("curl -sSf http://${netboot.serverAddress}/seeds/${host}/user-data | python3 -c 'import sys, yaml; seed = yaml.safe_load(sys.stdin); assert seed[\"hostname\"] == \"${host}\"; assert seed[\"write_files\"][0][\"path\"] == \"/usr/local/sbin/flash-os\"'")
          machine.succeed("systemctl stop netboot-rescue@${host}.service")
          machine.fail("curl -sSf tftp://${netboot.serverAddress}/${host}/config.txt > /dev/null")
          machine.succeed("test -d /var/lib/netboot/nfs/${host}")
          machine.succeed("showmount -e localhost | grep '/var/lib/netboot/nfs/${host}' > /dev/null")
          machine.wait_until_succeeds("test ! -e /var/lib/netboot/nfs/${host}", timeout=120)
          exports = machine.succeed("showmount -e localhost")
          assert "/var/lib/netboot/nfs/${host}" not in exports, f"Export of ${host} still listed after its removal: {exports!r}"
          print("Rescue toggle of ${host} verified: published, exported, withdrawn, and cleaned up!")
        '') netbootHosts}
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

        # Scrape the endpoint and ensure it serves comin metrics. Assert on
        # the metric name prefix rather than a specific metric: labeled
        # counters (e.g. comin_fetch_count) only appear after their first
        # increment, so asserting on one races comin's first fetch.
        machine.succeed("curl -sSf http://localhost:4243/metrics | grep -q '^comin_'")
        print("Prometheus metrics endpoint verified successfully!")
      '';
    in
    ''
      # Boot check (common to all hosts)
      machine.wait_for_unit("multi-user.target")

      # Every host (including mock fixtures) will evaluate these rules

      # Verify hostname configuration
      current_hostname = machine.succeed("hostname").strip()
      assert current_hostname == "${hostName}", f"Expected kernel hostname '${hostName}', but got: {current_hostname}"

      # Dynamic service assertions
      ${sshCheck}
      ${bootstrapKeyCheck}
      ${sudoCheck}
      ${qemuAgentCheck}
      ${nodeExporterCheck}
      ${sambaCheck}
      ${mosquittoCheck}
      ${netbootCheck}
      ${cominCheck}

      # Host-specific custom assertions (if any)
      ${extraTestScript}
    '';
}
