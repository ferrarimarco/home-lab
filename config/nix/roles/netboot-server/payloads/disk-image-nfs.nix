{
  lib,
  pkgs,
  paths,
  cfg,
  netboot,
  bootstrapPublicKeys,
  ...
}:

# A vendor disk image with a boot partition and a root filesystem, served as
# it is: the boot files over the platform's path, the root over NFS from a
# fresh per-host copy, customized at boot by the image's own cloud-init from
# a seed over HTTP. Raspberry Pi OS Lite is the first instance.
let
  yaml = pkgs.formats.yaml { };

  indent =
    text:
    lib.concatMapStringsSep "\n" (line: if line == "" then "" else "      ${line}") (
      lib.splitString "\n" (lib.removeSuffix "\n" text)
    );

  # Rendered by hand: the YAML generator folds the flash script into one
  # escaped string, and the seed is what an operator reads on the rescue
  # system when cloud-init misbehaves. The administrative user carries the
  # lab's bootstrap key and passwordless sudo; password login stays off.
  userData =
    { hostName, flashScript }:
    pkgs.writeText "user-data" ''
      #cloud-config
      hostname: ${hostName}
      manage_etc_hosts: true
      ssh_pwauth: false
      users:
        - name: pi
          groups: adm,sudo,users
          shell: /bin/bash
          lock_passwd: true
          sudo: "ALL=(ALL) NOPASSWD:ALL"
          ssh_authorized_keys:
      ${lib.concatMapStringsSep "\n" (key: "      - ${key}") bootstrapPublicKeys}
      ${lib.optionalString flashScript ''
        write_files:
          - path: /usr/local/sbin/flash-os
            permissions: "0755"
            content: |
        ${indent (builtins.readFile ../flash-os.sh)}
      ''}
    '';

  # The instance ID names the host and the purpose, so a seed is never taken
  # for one cloud-init already applied. The rescue seed comes over HTTP, so
  # the network stage fetches it, and it leaves the network the kernel
  # configured alone.
  seedFiles = hostName: {
    rescue = {
      user-data = userData {
        inherit hostName;
        flashScript = true;
      };
      meta-data = yaml.generate "meta-data" {
        instance-id = "rescue-${hostName}";
        dsmode = "net";
      };
      network-config = yaml.generate "network-config" { network.config = "disabled"; };
    };
    installed = {
      user-data = userData {
        inherit hostName;
        flashScript = false;
      };
      meta-data = yaml.generate "meta-data" {
        instance-id = "installed-${hostName}";
        dsmode = "local";
      };
      network-config = yaml.generate "network-config" {
        network = {
          version = 2;
          ethernets.eth0 = {
            dhcp4 = true;
            optional = false;
          };
        };
      };
    };
  };

  seedRules =
    hostName:
    lib.concatLists (
      lib.mapAttrsToList (
        kind: files:
        let
          dir = "${paths.httpDir}/${if kind == "rescue" then "seeds" else "installed"}/${hostName}";
        in
        [ "d ${dir} 0755 root root -" ]
        ++ lib.mapAttrsToList (fileName: file: "L+ ${dir}/${fileName} - - - - ${file}") files
      ) (seedFiles hostName)
    );

  imageRules =
    payloadName: payload:
    let
      dir = "${paths.httpDir}/images";
      checksum = pkgs.writeText "${payloadName}.img.xz.sha256" "${payload.sha256}  ${payloadName}.img.xz\n";
    in
    [
      "d ${dir} 0755 root root -"
      "L+ ${dir}/${payloadName}.img.xz - - - - ${paths.imagesDir}/${payloadName}.img.xz"
      "L+ ${dir}/${payloadName}.img.xz.sha256 - - - - ${checksum}"
    ];
in
{
  unitName = payloadName: "netboot-payload-${payloadName}.service";

  bootFilesDir = payloadName: "${paths.payloadsDir}/${payloadName}/boot";

  # NFSv3 over TCP without locking, what the image's initramfs (klibc
  # nfsmount) accepts; the seed URL is the kernel command line form of
  # cloud-init's NoCloud datasource.
  kernelParameters =
    hostName:
    lib.concatStringsSep " " [
      "root=/dev/nfs"
      "nfsroot=${cfg.serverAddress}:${paths.nfsDir}/${hostName},vers=3,tcp,nolock"
      "rw"
      "ip=dhcp"
      "rootwait"
      "ds=nocloud;s=http://${cfg.serverAddress}/seeds/${hostName}/"
    ];

  prepareExport = { hostName, payloadName }: "${netboot} prepare ${hostName} ${payloadName}";

  # A long-running service, not a oneshot: the activation that introduces a
  # pin would otherwise wait for the download. The toggle checks the payload's
  # readiness stamp instead of the unit's state.
  units = payloadName: payload: {
    "netboot-payload-${payloadName}" = {
      description = "Network boot payload ${payloadName}: fetch and unpack the pinned image";
      wantedBy = [ "multi-user.target" ];
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];
      serviceConfig = {
        Type = "exec";
        RemainAfterExit = true;
        Restart = "on-failure";
        RestartSec = "5min";
        ExecStart = "${netboot} fetch ${payloadName} ${payload.url} ${payload.sha256}";
      };
    };
  };

  tmpfilesRules =
    { payloads, hosts }:
    lib.concatLists (lib.mapAttrsToList imageRules payloads)
    ++ lib.concatLists (map seedRules (lib.attrNames hosts));
}
