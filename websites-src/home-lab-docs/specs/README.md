# Home Lab Design Specifications

This directory contains design specifications for various components of the home
lab infrastructure. These specifications focus on architecture, security, and
testing rationale before code implementation.

## Specifications Directory Index

| Specification                                                               | Description                                                                                                                                              | Current Implementation Status |
| :-------------------------------------------------------------------------- | :------------------------------------------------------------------------------------------------------------------------------------------------------- | :---------------------------- |
| [**Home Lab Bootstrapping**](./home-lab-bootstrapping.md)                   | Global VM installation infrastructure: Nix-native custom installer ISO, secure bootstrap key loading with Git-tracking guardrails, and `nixos-anywhere`. | **Fully Implemented**         |
| [**NixOS VMs on Proxmox**](./proxmox-vm.md)                                 | Reusable framework for NixOS VMs: the `proxmox-vm` role, host structure with Disko layouts, and the Terraform VM provisioning pattern.                   | **Fully Implemented**         |
| [**Declarative Integration Testing**](./declarative-integration-testing.md) | Design of the NixOS test generator framework (`make-test.nix`), dynamic test discovery, and parallel GHA matrix CI pipeline.                             | **Fully Implemented**         |
| [**NixOS LXC Containers on Proxmox**](./proxmox-lxc.md)                     | Reusable framework for NixOS LXC containers: the `proxmox-lxc` role, `system.build.tarball` templates, and the Terraform provisioning pattern.           | **Fully Implemented**         |
| [**NAS LXC Container**](./nas-lxc-container.md)                             | NixOS LXC containers on each Proxmox node exposing host ZFS datasets as SMB shares via bind mounts. Builds on the `proxmox-lxc` framework.               | **Fully Implemented**         |

## Specifications to write and TODOs

- Generate a Home Lab bootstrapping keypair.
- Fully automate Terraform runs. Reference:
  [Running Terraform in automation](https://developer.hashicorp.com/terraform/tutorials/automation/automate-terraform).
- Fully automate provisioning and configuration of new hosts. Currently manual
  steps:
    - Copy ESPHome secrets.
    - Configure the Ansible Vault password file and the per-host vault files.
    - Configure SSH keys.
    - Configure unattended updates:
      [Proxmox hosts](https://forum.proxmox.com/threads/is-unattended-upgrade-package-safe-to-use.139808/),
      Raspberry Pi hosts, Debian VMs, Nix hosts.
    - Migrate containers.
    - Run Ansible.
    - Run Terraform to set up the Proxmox hosts (networking; storage: pve1 done,
      pve2 pending).
- Configure static IP addresses for servers (raspberrypi2, hl01): when the
  router reboots, dnsmasq on the gateway doesn't know the hosts until they renew
  their DHCP leases, so their names don't resolve in the meantime.
- Minimize external dependencies:
    - NixOS ISO server host
    - Terraform provider registry
- Nix tests
    - Modularize the integration-test generator: move the per-service test
      fragments (SSH, QEMU guest agent, comin, Samba, ...) out of
      `config/nix/tests/make-test.nix` — for example placing each fragment next
      to its role — so the generator stays maintainable as service coverage
      grows. Do it for all services at once to avoid a split paradigm.
    - Check that configured users are present
    - Check that configured users have their SSH keys authorized (reuse the
      existing bootstrap key check because it already does most of the stuff we
      need for this check).
- Stable serial adapter assignment:
    - Create a udev rule:
      `echo 'SUBSYSTEM=="tty", ATTRS{idVendor}=="1a86", ATTRS{idProduct}=="55d4", SYMLINK+="zigbee_dongle"' | sudo tee /etc/udev/rules.d/99-zigbee.rules`
    - Change the mapping in Docker
    - Logs:

        ```text
        Error response from daemon: error gathering device information while adding custom device "/dev/serial/by-id/usb-ITEAD_SONOFF_Zigbee_3.0_USB_Dongle_Plus_V2_20220708144056-if00": no such file or directory
        pi@raspberrypi2:~ $ ls /dev/serial/by-id
        usb-1a86_USB_Single_Serial_54DD003512-if00
        ```

- Move monitoring stack from the home_lab_node role to the home_lab_monitoring
  role.
- raspberrypi2 stability follow-ups (freeze investigated on 2026-09-13: hard
  lockup between 13:39 and 13:42 local time with no kernel, undervoltage,
  thermal, or memory precursors in logs or Prometheus history):
    - Run a SMART long self-test on the WD30EZRX 3TB data disk (1 pending and 1
      offline-uncorrectable sector as of 2026-09-13, ~39200 power-on hours) and
      decide whether to plan a replacement. Verify the restic backups of that
      disk are current first.
    - Upgrade the operating system: Debian 11 (bullseye) is past LTS end of
      life, the April 2023 kernel is the most plausible lockup culprit, and the
      system Python 3.9 caps `requests` below 2.33, pinning the ONT exporter
      (2026-09-14) to a release with a known security vulnerability. Decide
      between an in-place dist-upgrade and a NixOS migration. After the upgrade,
      bump the `requests` pin and the CI requirements test matrix
      (`test-python-requirements.yaml`).
    - Optionally prove the hardware watchdog recovery path end-to-end with a
      deliberate kernel crash (`echo c > /proc/sysrq-trigger`): the host should
      self-reboot within the 15 second timeout. Induced crash with the usual
      unclean-shutdown cost, so schedule it consciously.
    - Prune the now-unreferenced `vault_raspberrypi2_monitoring_nut_*` variables
      from the raspberrypi2 Ansible vault (NUT moved to pve1; the host_vars
      references were removed on 2026-09-14).
- Validate the reworked `sense-hat-exporter` unit (venv in a systemd state
  directory, metrics file deleted on start and exit, throttled restarts; changed
  2026-09-14) whenever a host with a Sense HAT returns to service; no such host
  is currently deployed.
- ONT admin interface health: the ZTE ONT's admin interface sometimes hangs
  until the ONT is rebooted (it hung from 2026-03-28 until at least 2026-09-15,
  starving the ONT exporter; a manual reboot is still pending). The ONT is a
  closed, ISP-managed device, so root-causing is likely not possible; explore
  detecting the hang from monitoring (the exporter now fails visibly when it
  happens) and eventually automating the reboot (e.g. a smart plug power cycle),
  and assess whether that automation is worth the added failure modes.
  Actionability unclear at this point.
- Replace the `rm` ExecStartPre workaround in systemd units that write node
  exporter textfiles (e.g. monitoring-apt) with the `truncate:` variant of
  `StandardOutput` once every host runs systemd >= 248.
- Monitoring alerting: no Prometheus alerts are configured. Known gaps:
  temperature alerts (pve1 `coretemp` above 85 degrees Celsius, Coral TPU above
  90 degrees Celsius, identified during the August 2026 thermal incident),
  staleness of node exporter textfiles (alert on `node_textfile_mtime_seconds`),
  and unexpected reboots (alert on `node_boot_time_seconds` changing, so
  hardware-watchdog recoveries are noticed rather than silently absorbed).
- NixOS VMs ([NixOS VMs on Proxmox](./proxmox-vm.md)): factor the per-host
  Terraform VM resources into a shared module (or `for_each` over a host map)
  once a second NixOS VM exists, so the reference pattern is enforced by code
  rather than by convention.
- Cross-host workloads backup.
- NAS ([NAS LXC Container](./nas-lxc-container.md)):
    - **NFS support**: Re-introduce NFS sharing alongside SMB. Evaluate
      `nfs-kernel-server` in a privileged container versus the user-space
      NFS-Ganesha server, which can run in an unprivileged container.
    - **Automated template upload**: Replace the local-file push
      (`proxmox_virtual_environment_file` pointing at the local build artifact,
      per the framework pattern) with
      `proxmox_virtual_environment_download_file` pulling the template from a
      published URL, removing the need for a locally built artifact at
      `terraform apply` time.
    - **Samba performance tuning**: Benchmark before adding any tuning to the
      `nas` role. Modern Samba enables AIO by default, and the classic knobs
      interact (a non-zero `aio write size` disables `min receivefile size`), so
      tuning without measurement is at best a no-op.
    - **GitOps requires the `comin` role per host**: comin needs a hostname at
      build time, so it cannot ride in the shared, hostname-less bootstrap
      template (see
      [template generation](./proxmox-lxc.md#5-lxc-template-generation)). Each
      NAS host's `configuration.nix` must therefore import the `comin` role
      itself, which is installed by the one-time `nixos-rebuild switch` handoff.
      True zero-touch first-boot GitOps would require working around comin's
      build-time hostname model.
    - **Samba password automation**: Replace the imperative `smbpasswd` step
      ([SMB user management](./nas-lxc-container.md#72-imperative-part-one-time-setup))
      with a mechanism/material split that keeps secrets out of the public
      repository (committing encrypted secrets — e.g. `sops-nix` ciphertext —
      was considered and rejected: this repository's policy keeps even encrypted
      secrets untracked, and public Git history is immortal). Design: the `nas`
      role ships a oneshot systemd unit that, on every activation, reads a
      password file from a well-known path and pipes it into
      `smbpasswd -s -a ferrarimarco`; the Ansible layer that already manages the
      Proxmox nodes writes that file (root-only, `0600`) to
      `/var/lib/samba-state/nas-pveN/smb-password` from a vaulted (untracked)
      variable, so the container's existing `/var/lib/samba` bind mount delivers
      it. Container recreation then self-heals the password database, rotation
      is an Ansible run plus a unit restart, and disaster recovery reduces to
      the local Ansible vault, as for every other secret in the lab.
    - **SMB service discovery**: Enable Samba's WS-Discovery or Avahi for
      automatic share browsing on Windows and macOS clients.
    - **Static IP migration**: Transition from DHCP to static IP assignments
      defined in the NixOS configuration once the network spec is written.
    - **Terraform-managed ZFS pools (evaluated 2026-08, deferred)**: the
      `bpg/proxmox` provider (since 0.111.x) offers
      [`proxmox_node_disk_zfs`](https://registry.terraform.io/providers/bpg/proxmox/latest/docs/resources/node_disk_zfs)
      for node ZFS pool lifecycle. Transitioning the pool layer of the
      `setup_disks` role (see
      [dataset mount points](./nas-lxc-container.md#111-zfs-dataset-mount-points-on-the-host))
      to it was evaluated and rejected for now: its pool attributes (`devices`,
      `raidlevel`, `ashift`, `compression`) are write-only, so the Terraform
      config would be the same unverified documentation the `zfs_pools`
      inventory already is, with no drift detection; the provider manages pools
      only, so datasets and mount-point ownership would stay in Ansible,
      splitting the ZFS layer across two tools; and with the local Terraform
      state backend, losing state would invert the deliberate "pools are
      asserted, never created" stance into a pool-creation attempt on
      data-bearing devices at the next apply. Revisit when the provider gains
      readable pool attributes (real drift detection) or dataset management, or
      when a durable remote state backend is in place.
    - **Single source of truth for shares**: Derive the Samba share exports
      (NixOS), the bind mounts (Terraform), and the host datasets (Ansible
      `zfs_datasets`,
      [dataset mount points](./nas-lxc-container.md#111-zfs-dataset-mount-points-on-the-host))
      from one data structure — for example a Nix attrset emitted to `tfvars`
      via `nix eval` — so each share is declared once and the three halves
      cannot drift (see
      [per-host shares](./nas-lxc-container.md#51-adding-per-host-shares)).
