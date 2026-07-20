# Design Spec: NixOS LXC Containers on Proxmox

## Implementation Status

| Component / Feature            | Status                | Details                                                                                        |
| :----------------------------- | :-------------------- | :--------------------------------------------------------------------------------------------- |
| **NixOS LXC Template Package** | **Fully Implemented** | `nixos-lxc-bootstrap` flake package builds a `proxmox-lxc` tarball via `system.build.tarball`. |
| **`proxmox-lxc` Role**         | **Fully Implemented** | NixOS role for LXC-specific base configuration.                                                |
| **Terraform Provisioning**     | **Missing**           | Reusable LXC template upload (`proxmox_virtual_environment_file`) and container provisioning.  |

## 1. Goal

Provide a reusable framework for running NixOS-based LXC containers on the
Proxmox nodes. The framework defines three pieces: a base NixOS role that adapts
a system to the LXC environment, a flake package that builds a `proxmox-lxc`
container template from a NixOS closure, and a Terraform pattern that uploads
that template and provisions the container.

Workload specs build on this framework and add their service-specific roles,
shares, and host configurations. The [NAS LXC Container](./nas-lxc-container.md)
is the first consumer.

## 2. Rationale

### 2.1 Why LXC Instead of a VM

Many workloads (file sharing, small network daemons) are lightweight services
that do not need their own kernel, dedicated disk images, or UEFI firmware. LXC
containers share the host kernel, start in seconds, and consume minimal memory
overhead while still providing process and filesystem isolation.

### 2.2 Why NixOS Inside the Container

The existing infrastructure is fully declarative (NixOS hosts, Nix flake,
Terraform). Using a NixOS LXC container maintains consistency: services,
firewall rules, and user accounts are version-controlled and reproducible, and
the container template is produced by the same flake that builds every other
host.

## 3. `proxmox-lxc` Role (`config/nix/roles/proxmox-lxc/default.nix`)

A base role for any NixOS LXC container running on Proxmox, analogous to the
existing `proxmox-vm` role.

```nix
{ lib, modulesPath, ... }:

{
  imports = [
    (modulesPath + "/virtualisation/proxmox-lxc.nix")
  ];

  proxmoxLXC = {
    enable = true;
    privileged = false;
    manageNetwork = false; # Let systemd-networkd consume network contexts from PVE
    manageHostName = false; # Let the container extract its identity from /etc/hostname
  };

  # Suppress errors from standard hardware components that do not exist inside a container
  services.udev.enable = lib.mkForce false;
  powerManagement.enable = lib.mkForce false;

  # LXC containers share the host kernel; do not try to load kernel modules or modify sysctls
  boot.kernel.enable = lib.mkForce false;
  boot.modprobeConfig.enable = lib.mkForce false;

  # systemd-logind fails to monitor when it runs inside unprivileged containers
  systemd.services.systemd-logind.serviceConfig.Restart = "on-failure";

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
```

> **Note on privilege:** The base role defaults to
> `proxmoxLXC.privileged = false`, the safe default for generic containers.
> Workloads that bind-mount host-owned paths and need a direct UID/GID mapping
> (host `1000` = container `1000`) override this to `true` in their host
> `configuration.nix`. For the per-host override to merge cleanly, set the role
> default with `lib.mkDefault`.

## 4. Host Structure

LXC containers do not require hardware kernel parameter adjustments, partition
maps (Disko), or bootloader configurations. Because there is no low-level
physical file system or hardware configuration to exclude during sandboxed
integration testing, LXC hosts do not need the separate hardware file that VM
hosts carry.

Each container is described by a small set of files under its host directory:

```text
config/nix/hosts/<host>/
├── default.nix          # Flake entry point: imports configuration.nix
├── configuration.nix    # Container configuration (roles + service settings)
└── test-override.nix    # Optional test-only overrides (mock mounts, assertions)
```

- **`default.nix`** is what the flake discovers and builds as
  `nixosConfigurations.<host>`; its presence also registers the host for
  auto-generated integration tests. For an LXC host it simply imports
  `configuration.nix`.
- **`configuration.nix`** is the container configuration proper: it imports the
  roles and defines the host's settings. The test generator imports this file
  directly, composing it with `test-override.nix` rather than the full
  `default.nix`.
- **`test-override.nix`** (optional) supplies test-only tweaks; see
  [LXC test limitations](#7-lxc-specific-test-limitations).

## 5. LXC Template Generation

### 5.1 Template Package

A flake package builds a `proxmox-lxc`-format tarball from a NixOS closure using
`config.system.build.tarball` (provided by the upstream `proxmox-lxc.nix`
module). This mirrors the way the
[`nixos-installer`](./home-lab-bootstrapping.md#31-nix-native-custom-iso-confignixpackagesnixos-installernix)
package builds the installer ISO.

The implemented generic instance, `config/nix/packages/lxc-bootstrap.nix`,
builds a minimal image from the `proxmox-lxc` role plus the bootstrap SSH keys:

```nix
{
  nixpkgs,
  system,
  inputs,
  bootstrapPublicKeys,
}:

let
  lxcSystem = nixpkgs.lib.nixosSystem {
    inherit system;
    specialArgs = { inherit inputs bootstrapPublicKeys; };
    modules = [
      ../roles/proxmox-lxc
      (_: {
        users.users.root.openssh.authorizedKeys.keys = bootstrapPublicKeys;
      })
    ];
  };
in
lxcSystem.config.system.build.tarball
```

The template deliberately omits the `comin` role. comin requires a hostname at
build time (`networking.hostName` or `services.comin.hostname`), which a
generic, hostname-less template cannot provide — including it makes the build
fail. Workloads adopt GitOps instead by importing the `comin` role in their own
per-host `configuration.nix`, where the hostname is set. That configuration is
applied through the one-time `nixos-rebuild switch` handoff described in
[Continuous Deployment (GitOps)](./home-lab-bootstrapping.md#35-continuous-deployment-gitops),
after which comin maintains the container. No per-host template is built.

### 5.2 Flake Registration

```nix
packages.${system} = {
  nixos-lxc-bootstrap = import ./packages/lxc-bootstrap.nix {
    inherit nixpkgs system inputs bootstrapPublicKeys;
  };
  # Per-host templates add the host configuration to the module set.
};
```

### 5.3 Build Command

```bash
nix build .#nixos-lxc-bootstrap
# Output: result/tarball/nixos-system-x86_64-linux.tar.xz
```

The resulting tarball is uploaded to each Proxmox node's `local` storage as a
container template (see §6).

## 6. Infrastructure Provisioning (Terraform)

LXC containers are defined in
`config/terraform/220-proxmox-workloads/containers-pveN.tf` using the
`bpg/proxmox` provider's `proxmox_virtual_environment_container` resource. The
template is uploaded with a `proxmox_virtual_environment_file` resource so the
container depends on it directly.

```hcl
# Uploads the built NixOS LXC template to Proxmox
resource "proxmox_virtual_environment_file" "nixos_lxc_template_pve1" {
  provider = proxmox.pve1

  content_type = "vztmpl"
  datastore_id = "local"
  node_name    = var.proxmox_virtual_environment_hosts["pve1"].node_name

  source_file {
    path      = "${path.module}/../../../result/tarball/nixos-system-x86_64-linux.tar.xz"
    file_name = "nixos-lxc-pve1.tar.xz"
  }
}

resource "proxmox_virtual_environment_container" "example_pve1" {
  provider = proxmox.pve1

  description  = "Managed by Terraform - NixOS LXC"
  node_name    = var.proxmox_virtual_environment_hosts["pve1"].node_name
  vm_id        = 200
  unprivileged = true # Workloads bind-mounting host-owned paths may override to false
  started      = true

  features {
    nesting = true
  }

  cpu {
    cores = 2
  }

  memory {
    dedicated = 2048
    swap      = 512
  }

  network_interface {
    name        = "eth0"
    bridge      = "vmbr0"
    mac_address = "<pinned-mac-address>"
  }

  disk {
    datastore_id = "local-zfs"
    size         = 8 # GB - OS rootfs only; workload data is bind-mounted
  }

  operating_system {
    template_file_id = proxmox_virtual_environment_file.nixos_lxc_template_pve1.id
    type             = "unmanaged"
  }

  initialization {
    hostname = "example-pve1"
  }
}
```

### Key design decisions

- **`type = "unmanaged"`**: Prevents Proxmox from running OS-specific
  configuration hooks (e.g., Debian `cloud-init`) that are incompatible with
  NixOS.
- **`features.nesting = true`**: Required for NixOS `systemd` to function
  correctly inside LXC.
- **`unprivileged`**: A privileged container (`unprivileged = false`) maps host
  UID/GID directly, so bind-mounted host-owned paths retain their ownership
  without an `lxc.idmap`. That avoids raw LXC config keys (which the
  `bpg/proxmox` provider does not expose and would otherwise require a
  provisioner) at the cost of a weaker isolation boundary. Unprivileged is the
  default; workloads that bind-mount host-owned data opt into privileged.
- **Small OS disk**: The rootfs only needs enough space for the NixOS system
  closure. Workload data resides on bind-mounted host paths.
- **Bind mount parameterization**: Mounts are declared via standard Terraform
  variables and dynamically mapped, keeping host path details out of the core
  resource block.
- **Declarative template upload**: The template is uploaded using the
  `proxmox_virtual_environment_file` resource, creating a direct dependency via
  `template_file_id` that guarantees the template is uploaded before container
  creation.

## 7. LXC-Specific Test Limitations

The standard NixOS test framework runs tests inside QEMU VMs, not LXC
containers, so a container's LXC-specific settings would otherwise stop the test
VM from booting.

The test harness (`config/nix/tests/make-test.nix`) handles this automatically.
Whenever a host exposes the `proxmoxLXC` option — that is, it imports the
[`proxmox-lxc` role](#3-proxmox-lxc-role-confignixrolesproxmox-lxcdefaultnix) —
the harness injects the container-to-VM compatibility overrides:

- `boot.isContainer = false`, and re-enables the kernel, `udev`, and `modprobe`
  that the role disables for a real container.
- A mock root filesystem (`fileSystems."/"`).
- `proxmoxLXC.manageHostName = true`, so the test VM manages its own hostname.

A host's `test-override.nix` therefore does not set these itself; it only
supplies workload-specific mocks (for example bind-mount directories) and
assertions.

## 8. Terraform Provider Authentication

Bind mounts in the `bpg/proxmox` provider require authentication as `root@pam`.
The existing provider configuration already supports username/password
authentication alongside API tokens.
