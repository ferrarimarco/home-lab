# Design Spec: Proxmox VM Configuration for `hl02`

## Implementation Status

| Component / Feature       | Status                | Details                                            |
| :------------------------ | :-------------------- | :------------------------------------------------- |
| **Logical Host Config**   | **Fully Implemented** | Pinned hostname, DHCP, state version defined.      |
| **Physical Host Config**  | **Fully Implemented** | Standard physical entrypoint defined.              |
| **Disk Layout (Disko)**   | **Fully Implemented** | GPT, 512M ESP, 100% ext4 root partition defined.   |
| **Terraform VM Resource** | **Missing**           | `hl02` VM hardware definition needs to be added.   |
| **Host Integration Test** | **Missing**           | Host-specific test entrypoint needs to be created. |

## 1. Goal

Configure `hl02` as a fully defined NixOS Proxmox VM using DHCP, defined
declaratively with Disko partitioning, and provisioned automatically via
Terraform and `nixos-anywhere`.

## 2. Rationale

Currently, the configuration for `hl02` is incomplete and references a
non-existent `ext4` role, which prevents it from building. This spec defines the
specific configuration, partitioning, and provisioning parameters for `hl02` to
bring it into a fully declarative state.

It builds upon the global
[Home Lab Bootstrapping Spec](./home-lab-bootstrapping.md) for installation and
the [Declarative Integration Testing Spec](./declarative-integration-testing.md)
for CI/CD validation.

## 3. Proposed Changes

### 3.1 Host Configuration Split

Following the standard logical/physical split (see
[Testing Spec - Split Design](./declarative-integration-testing.md#31-logical-vs-physical-configuration-split)),
the files for `hl02` are structured under `config/nix/hosts/hl02/`:

- **`default.nix` (Physical Entrypoint):**
    - Imports `./configuration.nix` (logical settings).
    - Imports `./hardware.nix` (hardware placeholder).
    - Imports `./disko.nix` (filesystem configuration).
- **`configuration.nix` (Logical Config):**
    - Imports `roles/common` and `roles/proxmox-vm` (general VM optimizations).
    - Defines logical host parameters:
        - `networking.hostName = "hl02"`
        - `networking.hostId = "92bbb1e6"`
        - `networking.useDHCP = true`
        - `system.stateVersion = "25.11"`
- **`disko.nix` (Filesystem Config):**
    - Accepts `{ inputs, ... }` globally via `specialArgs`.
    - Imports the core Disko module (`inputs.disko.nixosModules.disko`).
    - Defines the physical ext4 disk layout on `/dev/vda`.
- **`hardware.nix` (Hardware Placeholder):**
    - Left as an empty placeholder `{ ... }` since standard VM hardware
      configurations (VirtIO drivers, systemd-boot) are generalized in the
      `roles/proxmox-vm` role.

### 3.2 File System Layout (`disko.nix`)

Declares a GPT partition table on the primary VirtIO virtual disk (`/dev/vda`):

- **EFI Partition (ESP):** 512MB, formatted as `vfat`, mounted at `/boot` with
  standard secure mount options.
- **Root Partition:** 100% of the remaining space, formatted as `ext4`, mounted
  at `/`.

### 3.3 Host-Specific Integration Test (`test.nix`)

Defines the test entrypoint for `hl02` by importing the global test generator:

```nix
{ pkgs, ... }:

import ../../tests/make-test.nix {
  inherit pkgs;
  hostConfiguration = ./configuration.nix;
}
```

This test is automatically discovered by the flake and verified in CI (see
[Testing Spec - Dynamic Discovery](./declarative-integration-testing.md#33-flake-integration-and-dynamic-test-discovery)).

## 4. Infrastructure Provisioning (Terraform)

We declare the VM hardware configuration in
`config/terraform/220-proxmox-workloads/vms-pve1.tf` using the `bpg/proxmox`
provider:

- **VM Resource (`proxmox_virtual_environment_vm.hl02`):**
    - **Hardware:** 2 Cores (Host type), 4GB dedicated RAM.
    - **EFI Disk & Storage:** EFI type `4m`, stored on `local-zfs` pool.
    - **Disk Interface (`virtio0`):** Presents the virtual disk as `/dev/vda`
      inside the VM, matching `disko.nix` expectations.
    - **Installer CDROM (`ide2`):** Mounts the custom installer ISO (uploaded
      automatically as described in
      [Bootstrapping Spec - Custom ISO](./home-lab-bootstrapping.md#31-nix-native-custom-iso-confignixpackagesnixos-installernix)).
    - **MAC Pinning:** Pins a static MAC address (`BC:24:11:D4:F6:65`) to the
      virtio network interface.
    - **Automated Boot Order:** Configures `boot_order = ["virtio0", "ide2"]`.
        - _First Boot:_ VM disk `/dev/vda` is empty, falls back to booting from
          the installer ISO on `ide2`.
        - _Subsequent Boots:_ Boots directly from the production system on
          `/dev/vda` (`virtio0`), bypassing the installer.

## 5. Assumptions & Constraints

### 5.1 Disk Device Configuration (`/dev/vda`)

The physical Disko configuration explicitly targets `/dev/vda`. This assumes the
Proxmox VM is provisioned using a **VirtIO Block** controller. If the VM is
provisioned using a **SCSI** controller, the disk will present as `/dev/sda` and
partitioning will fail.

- _Constraint:_ The VM must use a VirtIO Block disk interface in Terraform.

### 5.2 Networking (DHCP "For Now")

The host uses DHCP for simplicity in this phase. Transitioning to static IPs can
be done in a future specification.

### Host-Specific Parameters

1.  **Router DHCP Reservation:** Map MAC address `BC:24:11:D4:F6:65` to the
    designated IP for `hl02` in your router.
2.  **Installation Command:**
    ```bash
    nix develop .#operations -c nixos-anywhere --flake .#hl02 root@hl02.<fqdn>
    ```
