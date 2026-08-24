# Home Lab Design Specifications

This directory contains design specifications for various components of the home
lab infrastructure. These specifications focus on architecture, security, and
testing rationale before code implementation.

## Specifications Directory Index

| Specification                                                               | Description                                                                                                                                              | Current Implementation Status |
| :-------------------------------------------------------------------------- | :------------------------------------------------------------------------------------------------------------------------------------------------------- | :---------------------------- |
| [**Home Lab Bootstrapping**](./home-lab-bootstrapping.md)                   | Global VM installation infrastructure: Nix-native custom installer ISO, secure bootstrap key loading with Git-tracking guardrails, and `nixos-anywhere`. | **Fully Implemented**         |
| [**Proxmox VM Config (`hl02`)**](./hl02-proxmox-vm.md)                      | Host-specific virtual hardware, partition layouts (Disko), and Terraform definitions for `hl02`.                                                         | **Fully Implemented**         |
| [**Declarative Integration Testing**](./declarative-integration-testing.md) | Design of the NixOS test generator framework (`make-test.nix`), dynamic test discovery, and parallel GHA matrix CI pipeline.                             | **Fully Implemented**         |
| [**NixOS LXC Containers on Proxmox**](./proxmox-lxc.md)                     | Reusable framework for NixOS LXC containers: the `proxmox-lxc` role, `system.build.tarball` templates, and the Terraform provisioning pattern.           | **Fully Implemented**         |
| [**NAS LXC Container**](./nas-lxc-container.md)                             | NixOS LXC containers on each Proxmox node exposing host ZFS datasets as SMB shares via bind mounts. Builds on the `proxmox-lxc` framework.               | **Fully Implemented**         |

## Specifications to write and TODOs

- Generate a Home Lab bootstrapping keypair.
- Fully automate Terraform runs. Reference:
  [Running Terraform in automation](https://developer.hashicorp.com/terraform/tutorials/automation/automate-terraform).
- Fully automate provisioning and configuration of new hosts.
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
- Move monitoring stack from the home_lab_node role to the home_lab_monitoring
  role.
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
    - **Single source of truth for shares**: Derive the Samba share exports
      (NixOS), the bind mounts (Terraform), and the host datasets (Ansible
      `zfs_datasets`,
      [dataset mount points](./nas-lxc-container.md#111-zfs-dataset-mount-points-on-the-host))
      from one data structure — for example a Nix attrset emitted to `tfvars`
      via `nix eval` — so each share is declared once and the three halves
      cannot drift (see
      [per-host shares](./nas-lxc-container.md#51-adding-per-host-shares)).
