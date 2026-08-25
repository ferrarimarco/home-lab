# Design Spec: NixOS LXC Containers on Proxmox

## Implementation Status

| Component / Feature            | Status                | Details                                                                                        |
| :----------------------------- | :-------------------- | :--------------------------------------------------------------------------------------------- |
| **NixOS LXC Template Package** | **Fully Implemented** | `nixos-lxc-bootstrap` flake package builds a `proxmox-lxc` tarball via `system.build.tarball`. |
| **`proxmox-lxc` Role**         | **Fully Implemented** | NixOS role for LXC-specific base configuration; tunables use `lib.mkDefault` (§3).             |
| **Artifact Staging Package**   | **Fully Implemented** | `proxmox-images` aggregate staging the ISO and the LXC template under one `result` (§5.4).     |
| **Terraform Template Upload**  | **Fully Implemented** | `proxmox_virtual_environment_file` uploads the template to each node's `local` storage (§6.1). |

## 1. Goal

Provide a reusable framework for running NixOS-based LXC containers on the
Proxmox nodes. The framework defines three pieces: a base NixOS role that adapts
a system to the LXC environment, a flake package that builds a `proxmox-lxc`
container template from a NixOS closure, and the Terraform configuration that
stages that template and uploads it to every node.

Workload specs build on this framework: they add their service-specific roles,
shares, and host configurations, and declare their own container resources
following the reference pattern in [§6.2](#62-container-reference-pattern). The
[NAS LXC Container](./nas-lxc-container.md) is the first consumer.

## 2. Rationale

### 2.1 Why LXC Instead of a VM

Many workloads (file sharing, small network daemons) are lightweight services
that do not need their own kernel, dedicated disk images, or UEFI firmware. LXC
containers share the host kernel, start in seconds, and consume minimal memory
overhead while still providing process and filesystem isolation.

For workloads that serve data from the host's own storage, LXC has a further
advantage: a bind mount passes a host directory straight through to the
container, so I/O lands directly on the host filesystem. A VM instead keeps its
data on a virtual disk — a guest filesystem layered on a zvol or image file on
top of the host filesystem — stacking one filesystem on another and paying the
resulting write-amplification overhead. Bind mounts avoid that entirely.

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

    # Workload-tunable options are set with lib.mkDefault so service roles
    # and host configurations can override them with plain values.
    privileged = lib.mkDefault false;

    # With these disabled, the container consumes what PVE's nixos ostype
    # hooks write into it at start: the systemd-networkd configuration and
    # /etc/hostname. Hosts that pin networking.hostName (every comin
    # workload) must override manageHostName to true: the upstream module
    # otherwise forces networking.hostName to "" and comin asserts at build
    # time that it is non-empty. See the hostname note in the proxmox-lxc
    # spec.
    manageNetwork = lib.mkDefault false;
    manageHostName = lib.mkDefault false;
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
> (host `1000` = container `1000`) override this to `true` in their service role
> or host `configuration.nix` (the
> [NAS spec](./nas-lxc-container.md#4-nas-role-confignixrolesnasdefaultnix) does
> it in its `nas` role). Because the role sets the default with `lib.mkDefault`,
> the override is a plain `true` — no `lib.mkForce` needed.

> **Note on hostname (required for GitOps hosts):** When both
> `manageNetwork = false` and `manageHostName = false`, the upstream
> `proxmox-lxc.nix` module sets `networking.hostName = lib.mkForce ""` so the
> runtime hostname comes from the PVE-written `/etc/hostname`. That `mkForce`
> silently discards any plain `networking.hostName = "<host>"` a host sets — and
> comin asserts at evaluation time that its hostname is non-empty, so a GitOps
> host's production closure fails to build. Any host that pins a hostname (every
> comin workload) must therefore also set `proxmoxLXC.manageHostName = true`
> alongside `networking.hostName`. Only the hostname-less bootstrap template
> (§5.1) keeps `manageHostName = false`. Beware that the integration-test
> harness overrides `manageHostName` itself (see
> [§7](#7-lxc-specific-test-limitations)), so host tests cannot catch a missing
> override; only evaluating the production closure surfaces it. The CI machine
> matrix does exactly that for every deployable host (see the
> [testing spec](./declarative-integration-testing.md#4-github-actions-workflow-update-githubworkflowsnixyaml)).

## 4. Host Structure

LXC containers do not require hardware kernel parameter adjustments, partition
maps (Disko), or bootloader configurations. Because there is no low-level
physical file system or hardware configuration to exclude during sandboxed
integration testing, LXC hosts do not need the separate disk-layout
(`disko.nix`) file that [VM hosts](./proxmox-vm.md#4-host-structure) carry.

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
  lxcModules = [
    ../roles/proxmox-lxc

    (_: {
      users.users.root.openssh.authorizedKeys.keys = bootstrapPublicKeys;

      # Pin the release the bootstrap image was built against.
      system.stateVersion = "25.11";
    })
  ];

  lxcSystem = nixpkgs.lib.nixosSystem {
    inherit system;
    specialArgs = { inherit inputs bootstrapPublicKeys; };
    modules = lxcModules;
  };

  inherit (lxcSystem.config.system.build) tarball;
in
tarball
// {
  modules = lxcModules;
  inherit bootstrapPublicKeys;
}
```

The package exposes its module list (`modules`) and the bootstrap keys as
passthrough attributes. The passthrough is load-bearing for testing: the
`minimal-lxc` fixture's `test-override.nix` imports `lxcBootstrap.modules`, so
its integration test exercises exactly the module set the template ships rather
than a parallel reconstruction of it.

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
# Output: result/tarball/nixos-image-<label>-x86_64-linux.tar.xz
# The label embeds the module's system.nixos.tags plus release, date, and
# commit. Example:
# result/tarball/nixos-image-lxc-proxmox-25.11.20260417.c7f4703-x86_64-linux.tar.xz
```

The tarball filename comes from `image.baseName`, which embeds the NixOS label
(release, date, and commit) — the same behavior as the installer ISO. Terraform
therefore matches it with a filename pattern rather than a fixed path (see §6);
the versioned name is also what makes template rebuilds visible to Terraform,
since a rebuilt template changes the source path.

The resulting tarball is uploaded to each Proxmox node's `local` storage as a
container template (see §6). Before running Terraform, stage the artifact with
the aggregate package described in
[§5.4](#54-artifact-staging-for-terraform-proxmox-images).

### 5.4 Artifact Staging for Terraform (`proxmox-images`)

`nix build` refreshes the single `result` symlink to point at the last-built
package, so the installer ISO (`result/iso/...`) and the LXC template
(`result/tarball/...`) cannot coexist behind it when built individually:
whichever artifact was built last breaks the Terraform lookup for the other one.

The `proxmox-images` aggregate package solves this without custom output links:
it symlinks the artifact directories of both image packages into one output, so
a single build stages everything Terraform reads:

```nix
# config/nix/packages/proxmox-images.nix
# Registered in the flake like the other packages.
{
  pkgs,
  nixosInstaller,
  nixosLxcBootstrap,
}:

pkgs.runCommand "proxmox-images" { } ''
  mkdir --parents "$out"
  ln --symbolic ${nixosInstaller}/iso "$out/iso"
  ln --symbolic ${nixosLxcBootstrap}/tarball "$out/tarball"
''
```

```bash
nix build .#proxmox-images
# result/iso/nixos-minimal-<label>-x86_64-linux.iso
# result/tarball/nixos-image-<label>-x86_64-linux.tar.xz
```

Run this build before `terraform apply`. The Terraform lookups (the ISO upload
and the template upload in §6) address the artifacts through literal
`result/iso/...` and `result/tarball/...` path segments, with globbing only on
the filename, so the directory symlinks resolve transparently. The individual
packages remain buildable on their own for development.

Because the aggregate is a flake package, the CI package matrix discovers and
builds it automatically, which also verifies that the staging layout stays
intact.

## 6. Infrastructure Provisioning (Terraform)

The framework's Terraform footprint is the **template upload** (§6.1), which it
owns and implements. Containers themselves are not a framework component: each
workload spec declares its own `proxmox_virtual_environment_container` resources
following the **reference pattern** in §6.2 and tracks them in its own status
table (the [NAS spec](./nas-lxc-container.md) is the first).

### 6.1 Template Upload (`images-templates.tf`)

The template is uploaded to each node's `local` storage with a
`proxmox_virtual_environment_file` resource in
`config/terraform/220-proxmox-workloads/images-templates.tf`, so containers can
depend on it directly via `template_file_id`. The local artifact it reads is
staged by the `proxmox-images` package
([§5.4](#54-artifact-staging-for-terraform-proxmox-images)). The `pve2` resource
mirrors the `pve1` one shown here:

```hcl
# Uploads the built NixOS LXC template to Proxmox
resource "proxmox_virtual_environment_file" "nixos_lxc_template_pve1" {
  provider = proxmox.pve1

  content_type = "vztmpl"
  datastore_id = "local"
  node_name    = var.proxmox_virtual_environment_hosts["pve1"].node_name

  source_file {
    # The tarball name embeds the NixOS version, date, and commit (see
    # section 5.3), so match it with a filename pattern, as the installer
    # ISO upload already does. The versioned name also means a rebuilt
    # template changes the source path and forces a re-upload; a stable
    # name would never re-upload.
    path      = "${local.nix_root_path}/${one(fileset(local.nix_root_path, "result/tarball/nixos-image-*-x86_64-linux.tar.xz"))}"
    file_name = "nixos-lxc-pve1.tar.xz"
  }
}
```

### 6.2 Container Reference Pattern

This section is a **reference pattern, not a framework deliverable**: the
framework ships no container of its own, so nothing here appears in the
implementation status table. Workload specs define their containers in
`config/terraform/220-proxmox-workloads/containers-pveN.tf` following this
shape:

```hcl
resource "proxmox_virtual_environment_container" "example_pve1" {
  provider = proxmox.pve1

  description  = "Managed by Terraform - NixOS LXC"
  node_name    = var.proxmox_virtual_environment_hosts["pve1"].node_name
  vm_id        = 200 # VMIDs are cluster-unique; pick an unused one per container
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
    type             = "nixos"
  }

  initialization {
    hostname = "example-pve1"

    ip_config {
      ipv4 {
        address = "dhcp"
      }
    }
  }
}
```

#### Key design decisions

- **`type = "nixos"`**: Selects PVE's native NixOS setup plugin
  (`PVE::LXC::Setup::NixOS`), which writes the container's systemd-networkd
  configuration and `/etc/hostname` at start. The `proxmox-lxc` role depends on
  this: `manageNetwork = false` enables systemd-networkd inside the container
  precisely to consume the network files PVE writes, and the upstream tarball
  even ships an empty `etc/systemd/network/` directory for PVE to fill.
  `unmanaged` would skip all setup hooks and leave the container with no IP
  configuration and no `/etc/hostname`.
- **DHCP via `initialization.ip_config`**: This block is what PVE renders into
  the container's networkd configuration, so it must be present for the
  container to request an address.
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

- `boot.isContainer = false`, disabling the container init script
  (`boot.loader.initScript`), and re-enabling the kernel, `udev`, and `modprobe`
  that the role disables for a real container.
- A mock root filesystem (`fileSystems."/"`).
- `proxmoxLXC.manageHostName = true`, so the test VM manages its own hostname.
  Note this masks the production hostname behavior — see the note on hostname in
  [§3](#3-proxmox-lxc-role-confignixrolesproxmox-lxcdefaultnix).

A host's `test-override.nix` therefore does not set these itself; it only
supplies workload-specific mocks (for example bind-mount directories) and
assertions.

## 8. Terraform Provider Authentication

Bind mounts in the `bpg/proxmox` provider require authentication as `root@pam`
with a password: the check is hardcoded in Proxmox (no role or ACL can grant it
to another principal, and a `root@pam` API token does not pass it either). The
existing provider configuration already supports username/password
authentication alongside API tokens.

`scripts/run-terraform.sh` therefore runs the `220-proxmox-workloads` service
with the same root credentials file (`proxmox-root-secrets.tfvars`) and
skip-if-missing gate as `200-proxmox-iac-automation-init`, instead of the
generated API token secrets. The two files define the same secrets variable and
Terraform takes the last definition of a variable, so the tokens would be
superseded anyway.
