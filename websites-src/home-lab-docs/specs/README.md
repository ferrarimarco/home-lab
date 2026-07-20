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
| [**NixOS LXC Containers on Proxmox**](./proxmox-lxc.md)                     | Reusable framework for NixOS LXC containers: the `proxmox-lxc` role, `system.build.tarball` templates, and the Terraform provisioning pattern.           | **Partially Implemented**     |
| [**NAS LXC Container**](./nas-lxc-container.md)                             | NixOS LXC containers on each Proxmox node exposing host ZFS datasets as SMB shares via bind mounts. Builds on the `proxmox-lxc` framework.               | **Not Implemented**           |

## Specifications to write / TODOs

- Generate a Home Lab bootstrapping keypair.
- Fully automate Terraform runs. Reference:
  [Running Terraform in automation](https://developer.hashicorp.com/terraform/tutorials/automation/automate-terraform).
- Fully automate provisioning and configuration of new hosts.
- Minimize external dependencies:
    - NixOS ISO server host
    - Terraform provider registry
- Nix tests
    - Check that configured users are present
    - Check that configured users have their SSH keys authorized (reuse the
      existing bootstrap key check because it already does most of the stuff we
      need for this check).
- Stable serial adapter assignment:
    - Create a udev rule:
      `echo 'SUBSYSTEM=="tty", ATTRS{idVendor}=="1a86", ATTRS{idProduct}=="55d4", SYMLINK+="zigbee_dongle"' | sudo tee /etc/udev/rules.d/99-zigbee.rules`
    - Change the mapping in Docker
