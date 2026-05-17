# Home Lab Design Specifications

This directory contains design specifications for various components of the home
lab infrastructure. These specifications focus on architecture, security, and
testing rationale before code implementation.

## Specifications Directory Index

| Specification                                                               | Description                                                                                                                                              | Current Implementation Status                                                                                                                                        |
| :-------------------------------------------------------------------------- | :------------------------------------------------------------------------------------------------------------------------------------------------------- | :------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| [**Proxmox VM Config (`hl02`)**](./hl02-proxmox-vm.md)                      | Host-specific virtual hardware, partition layouts (Disko), and Terraform definitions for `hl02`.                                                         | **Partially Implemented** (Logical/physical configs and ext4 Disko layouts are complete. Missing: Terraform VM resource definition and integration test entrypoint). |
| [**Declarative Integration Testing**](./declarative-integration-testing.md) | Design of the NixOS test generator framework (`make-test.nix`), dynamic test discovery, and parallel GHA matrix CI pipeline.                             | **Partially Implemented** (Core testing framework and dynamic Flake checks are in place. Missing: `specialArgs` mocking and GHA workflow update).                    |
| [**Home Lab Bootstrapping**](./home-lab-bootstrapping.md)                   | Global VM installation infrastructure: Nix-native custom installer ISO, secure bootstrap key loading with Git-tracking guardrails, and `nixos-anywhere`. | **Partially Implemented** (Operations shell includes `terraform` but lacks `nixos-anywhere`. Missing: custom ISO package, secure key loaders, and Git guardrails).   |
