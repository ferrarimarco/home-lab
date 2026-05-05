# Design Spec: Proxmox VM Configuration & Declarative Integration Testing for `hl02`

## 1. Goal
Configure `hl02` as a fully defined NixOS Proxmox VM using DHCP, and implement a Nix-native integration test framework to verify the configuration (system boot, SSH, and QEMU Guest Agent) both locally and in GitHub Actions.

## 2. Rationale
Currently, the configuration for `hl02` is incomplete and references a non-existent `ext4` role, which prevents it from building. Additionally, verifying VM configurations manually or via ad-hoc shell scripts in CI is brittle and hard to maintain. Transitioning to a declarative testing model using NixOS's native testing framework (`nixosTest`) ensures that configuration correctness is verified inside the Nix sandbox, providing reliable and reproducible feedback.

## 3. Proposed Changes

### 3.1 Architectural Split of `hl02` Configuration
To allow the integration test to run without triggering physical disk partitioning (which is handled by Disko and is not suitable for standard sandboxed NixOS tests), we split the host configuration:

*   **`config/nix/hosts/hl02/configuration.nix` (Logical Config):**
    *   Imports `roles/common` and `roles/proxmox-vm`.
    *   Configures logical settings:
        *   `networking.hostName = "hl02"`
        *   `networking.hostId = "92bbb1e6"`
        *   `networking.useDHCP = true`
        *   `system.stateVersion = "25.11"`
*   **`config/nix/hosts/hl02/default.nix` (Physical/Target Config):**
    *   Imports `inputs.disko.nixosModules.disko`.
    *   Imports `./configuration.nix` (the logical configuration).
    *   Imports `./hardware.nix` (empty placeholder for now).
    *   Imports `./disko.nix` (defines physical ext4 disk layout on `/dev/vda`).

### 3.2 Declarative Integration Test (`config/nix/hosts/hl02/test.nix`)
We define a NixOS integration test using `pkgs.nixosTest`:
*   **Node Definition:** A test node named `machine` that imports `hosts/hl02/configuration.nix`.
*   **Assertions:** A Python-based test script that executes:
    ```python
    machine.wait_for_unit("multi-user.target")
    machine.wait_for_open_port(22)
    machine.succeed("systemctl is-active qemu-guest-agent")
    ```

### 3.3 Flake Integration (`config/nix/flake.nix`)
Expose the new test in the flake's `checks` output for the `x86_64-linux` system:
*   Add `hl02-test` to `checks.${system}` by importing `hosts/hl02/test.nix`.
*   This allows `nix flake check` to automatically run the integration test.

### 3.4 GitHub Actions Workflow Update (`.github/workflows/nix.yaml`)
*   Maintain the `Check the main flake` step which runs `nix flake check` (this will now execute the `nixosTest` via QEMU).
*   Maintain the `Build the hl02 configuration` step to ensure the full physical VM image (with Disko) builds.
*   Remove the legacy `Smoke test - boot hl02` step which used a manual shell-based timeout.

## 4. Verification Plan

### 4.1 Automated Tests (CI)
*   Push the branch to GitHub and verify that the `nix flake check` step successfully executes and passes the `hl02-test` integration test.
*   Verify that the build step successfully completes.

### 4.2 Manual Verification (Local/Dev)
*   If Nix is available on the development machine, run `nix flake check` to run the test locally. (Note: Disallowed on the current host per user request).

## 5. Assumptions & Constraints

### 5.1 Disk Device Configuration (`/dev/vda`)
The physical Disko configuration (`hosts/hl02/disko.nix`) explicitly configures the target disk as `/dev/vda`. This assumes that the Proxmox VM is provisioned using a **VirtIO Block** controller. If the VM is provisioned using a **SCSI** controller (which is common in Proxmox), the disk will present as `/dev/sda` and the boot partition layout will fail to apply. 
*   *Constraint:* The VM must be created with a VirtIO Block disk controller, or `hosts/hl02/disko.nix` must be updated to `/dev/sda` to match a SCSI setup.

### 5.2 Empty `hardware.nix` Rationale
The file `hosts/hl02/hardware.nix` is currently an empty placeholder. This is because all VM-specific hardware configurations (such as standard VirtIO drivers, systemd-boot configuration, and kernel serial console parameters) are generalized in `roles/proxmox-vm/default.nix`. If `hl02` requires host-specific hardware modifications in the future (e.g., PCI passthrough), they should be declared in `hosts/hl02/hardware.nix`.

### 5.3 "For Now" Scope
*   **Networking:** The host uses DHCP for convenience and simplicity in this phase (`networking.useDHCP = true`). Transitioning to static IPs can be done in a future specification.
*   **User Access:** SSH keys are left unconfigured for this host in the Nix configuration. Initial login must be performed via console or by injecting keys out-of-band, until secret management (such as `sops-nix` or hardcoded public keys) is specified.
