{
  config,
  lib,
  pkgs,
  bootstrapPublicKeys,
  ...
}:

# Boot server of the Network Boot Service specification: a host network-boots
# only while its rescue toggle is started. Platforms (how a host finds the
# server and fetches its boot files) and payload types (what it runs once
# booted) live in their own files, so adding one adds a file.
let
  cfg = config.homeLab.netboot;

  paths = rec {
    stateDir = "/var/lib/netboot";
    runDir = "/run/netboot";
    imagesDir = "${stateDir}/images";
    payloadsDir = "${stateDir}/payloads";
    nfsDir = "${stateDir}/nfs";
    httpDir = "${stateDir}/http";
    tftpDir = "${runDir}/tftp";
  };

  # The steps the units run, as one command with subcommands.
  netboot = "${
    pkgs.writeShellApplication {
      name = "netboot";
      # coreutils included: the export cleanup runs as a transient unit,
      # without the default path of the declared units.
      runtimeInputs = with pkgs; [
        coreutils
        curl
        xz
        util-linux
        nfs-utils
        systemd
      ];
      runtimeEnv = {
        NETBOOT_IMAGES_DIR = paths.imagesDir;
        NETBOOT_PAYLOADS_DIR = paths.payloadsDir;
        NETBOOT_NFS_DIR = paths.nfsDir;
        NETBOOT_TFTP_DIR = paths.tftpDir;
        NETBOOT_RUN_DIR = paths.runDir;
        # Root filesystems, so root squashing is off; the client list and the
        # firewall limit who can reach them.
        NETBOOT_EXPORT_OPTIONS = "rw,sync,no_subtree_check,no_root_squash";
      };
      text = builtins.readFile ./scripts/netboot.sh;
    }
  }/bin/netboot";

  # Every file under platforms/ and payloads/ registers itself under its
  # basename, the way the flake discovers hosts; a file takes what it needs
  # from the shared arguments.
  importDir =
    dir:
    lib.mapAttrs'
      (
        fileName: _:
        lib.nameValuePair (lib.removeSuffix ".nix" fileName) (
          import (dir + "/${fileName}") {
            inherit
              lib
              pkgs
              paths
              cfg
              netboot
              bootstrapPublicKeys
              ;
          }
        )
      )
      (
        lib.filterAttrs (fileName: type: type == "regular" && lib.hasSuffix ".nix" fileName) (
          builtins.readDir dir
        )
      );

  platforms = importDir ./platforms;
  payloadTypes = importDir ./payloads;

  payloadTypeOf = payloadName: payloadTypes.${cfg.payloads.${payloadName}.type};

  # One fully specified unit per host rather than a template: the payload unit
  # a host requires and the commands it runs depend on its declaration.
  rescueUnits = lib.mapAttrs' (
    hostName: host:
    let
      platform = platforms.${host.platform};
      payloadType = payloadTypeOf host.payload;
      cleanupUnit = "netboot-export-cleanup-${hostName}";
      bootConfig = platform.renderBootConfig {
        inherit hostName;
        kernelParameters = payloadType.kernelParameters hostName;
      };
      dependencies = [
        (payloadType.unitName host.payload)
        "dnsmasq.service"
        "nfs-server.service"
        "nginx.service"
      ];
    in
    lib.nameValuePair "netboot-rescue@${hostName}" {
      description = "Network boot rescue of ${hostName}";
      # Wants, not requires, and no restart on a redeploy: a restart would
      # rebuild the export under a host still running from it, and a rescue
      # must survive the daemons' restarts and the role's own changes.
      wants = dependencies;
      after = dependencies;
      restartIfChanged = false;
      stopIfChanged = false;
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        # The start copies a root tree of a few gigabytes.
        TimeoutStartSec = "15min";
        ExecStart = [
          # A start during the grace period of a previous stop cancels the
          # removal the stop scheduled.
          "${netboot} cancel-removal ${hostName}"
          (payloadType.prepareExport {
            inherit hostName;
            payloadName = host.payload;
          })
          "${netboot} export ${hostName} \"${cfg.clientNetwork}\""
          (platform.publish {
            inherit hostName bootConfig;
            bootFilesDir = payloadType.bootFilesDir host.payload;
          })
        ];
        ExecStop = [
          (platform.withdraw { inherit hostName; })
          # The host still runs from the export and reboots afterwards.
          "${pkgs.systemd}/bin/systemd-run --on-active=${cfg.exportRemovalDelay} --timer-property=AccuracySec=1s --unit=${cleanupUnit} ${netboot} remove-export ${hostName}"
        ];
      };
    }
  ) cfg.hosts;

  hostsOfPayloadType =
    typeName: lib.filterAttrs (_: host: cfg.payloads.${host.payload}.type == typeName) cfg.hosts;
  usedPlatforms = lib.unique (lib.mapAttrsToList (_: host: host.platform) cfg.hosts);
in
{
  options.homeLab.netboot = {
    enable = lib.mkEnableOption "the network boot server";

    serverAddress = lib.mkOption {
      type = lib.types.str;
      description = "The reserved address the clients reach the server at: the proxy DHCP reply and the rendered boot configuration carry it.";
    };

    interface = lib.mkOption {
      type = lib.types.str;
      description = "The interface facing the lab network, the only one the firewall admits the boot services on.";
    };

    clientNetwork = lib.mkOption {
      type = lib.types.str;
      description = "The network the NFS exports are limited to, in exports(5) client syntax.";
    };

    exportRemovalDelay = lib.mkOption {
      type = lib.types.str;
      default = "10min";
      description = "How long an export outlives a stop of its toggle, as a systemd time span: the host runs from it until it reboots. The hl02 test shortens it to observe the removal.";
    };

    hosts = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            platform = lib.mkOption {
              type = lib.types.enum (lib.attrNames platforms);
              description = "How the host finds the server and fetches its boot files.";
            };
            payload = lib.mkOption {
              type = lib.types.str;
              description = "The name of the payload the host boots, from the payloads option.";
            };
          };
        }
      );
      default = { };
      description = "The hosts the server can network-boot, keyed by the name their toggle and their trees use.";
    };

    payloads = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            type = lib.mkOption {
              type = lib.types.enum (lib.attrNames payloadTypes);
              description = "How the payload is fetched, prepared for a host, and booted.";
            };
            url = lib.mkOption {
              type = lib.types.str;
              description = "Where the pinned image is downloaded from.";
            };
            sha256 = lib.mkOption {
              type = lib.types.strMatching "[0-9a-f]{64}";
              description = "The SHA-256 of the pinned image, verified after the download.";
            };
          };
        }
      );
      default = { };
      description = "The payloads the server can boot a host into.";
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        assertions = lib.mapAttrsToList (hostName: host: {
          assertion = cfg.payloads ? ${host.payload};
          message = "homeLab.netboot.hosts.${hostName} names the payload ${host.payload}, which homeLab.netboot.payloads does not declare.";
        }) cfg.hosts;

        # Raspberry Pi OS Lite: the rescue system and the image the flash
        # workflow installs, bumped like the other pinned artifacts.
        homeLab.netboot.payloads.raspios-lite = {
          type = lib.mkDefault "disk-image-nfs";
          url = lib.mkDefault "https://downloads.raspberrypi.com/raspios_lite_arm64/images/raspios_lite_arm64-2026-10-06/2026-10-06-raspios-trixie-arm64-lite.img.xz";
          sha256 = lib.mkDefault "483db18a48da399b5b7022ffae9a07bc6d99daab30e593aedac09b69ff422843";
        };

        # The payload units loop-mount the downloaded images.
        boot.kernelModules = [ "loop" ];

        systemd.tmpfiles.rules = [
          "d ${paths.stateDir} 0755 root root -"
          "d ${paths.imagesDir} 0755 root root -"
          "d ${paths.payloadsDir} 0755 root root -"
          "d ${paths.nfsDir} 0755 root root -"
          # A server reboot puts every host back in normal boot, so the
          # exports go with it: a boot-only rule, because an age rule would
          # let the daily cleaner delete the untouched files of a live export.
          "R! ${paths.nfsDir}/*"
          "d /etc/exports.d 0755 root root -"
          "R! /etc/exports.d/netboot-*.exports"
          "d ${paths.httpDir} 0755 root root -"
          "d ${paths.runDir} 0755 root root -"
          "d ${paths.tftpDir} 0755 root root -"
        ]
        ++ lib.concatMap (
          typeName:
          payloadTypes.${typeName}.tmpfilesRules {
            payloads = lib.filterAttrs (_: payload: payload.type == typeName) cfg.payloads;
            hosts = hostsOfPayloadType typeName;
          }
        ) (lib.attrNames payloadTypes);

        systemd.services =
          rescueUnits
          // lib.concatMapAttrs (
            payloadName: payload: payloadTypes.${payload.type}.units payloadName payload
          ) cfg.payloads;

        # The boot server every platform shares: a proxy DHCP responder that
        # answers the PXE part of a client's discover with the entries of the
        # platforms in use, leaving the leases to the router, and the TFTP
        # server on the runtime tree. No DNS.
        services.dnsmasq = {
          enable = true;
          resolveLocalQueries = false;
          settings = {
            port = 0;
            dhcp-range = "${cfg.serverAddress},proxy";
            pxe-service = lib.concatMap (platformName: platforms.${platformName}.pxeServices) usedPlatforms;
            enable-tftp = true;
            tftp-root = paths.tftpDir;
            log-dhcp = true;
          };
        };

        # The exports are the toggles' files under /etc/exports.d, none here.
        services.nfs.server = {
          enable = true;
          # Fixed so the firewall can admit the NFSv3 mount request.
          mountdPort = 20048;
        };
        # The clients mount NFSv3 with nolock, so lockd and statd stay closed.
        services.nfs.settings.nfsd = {
          vers3 = true;
          vers4 = false;
        };

        services.nginx = {
          enable = true;
          virtualHosts.netboot = {
            default = true;
            listen = [
              {
                addr = "0.0.0.0";
                port = 80;
              }
            ];
            root = paths.httpDir;
            locations."/".extraConfig = "autoindex on;";
          };
        };

        networking.firewall.interfaces.${cfg.interface} = {
          allowedTCPPorts = [
            80 # the cloud-init seeds and the images
            111 # rpcbind, the NFSv3 port lookup
            2049 # nfsd
            config.services.nfs.server.mountdPort
          ];
          allowedUDPPorts = [
            67 # DHCP discovers, broadcast by the clients
            69 # TFTP
            111
            4011 # proxy DHCP requests
            config.services.nfs.server.mountdPort
          ];
        };
      }
    ]
  );
}
