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

## Specifications to write

- Generate a Home Lab bootstrapping keypair.
