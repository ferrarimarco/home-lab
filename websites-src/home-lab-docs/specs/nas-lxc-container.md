# Design Spec: NAS LXC Container for SMB File Sharing

This spec builds on the [NixOS LXC Containers on Proxmox](./proxmox-lxc.md)
framework, which defines the `proxmox-lxc` role, LXC template generation, the
Terraform container-provisioning pattern, and LXC test limitations. This
document covers only the NAS/SMB-specific additions.

## Implementation Status

| Component / Feature             | Status                | Details                                                                                        |
| :------------------------------ | :-------------------- | :--------------------------------------------------------------------------------------------- |
| **`nas` Role (SMB)**            | **Fully Implemented** | NixOS role enabling Samba with declarative share definitions.                                  |
| **`common` Role UID Pin**       | **Fully Implemented** | `ferrarimarco` UID pinned to `1000`; verified a no-op on deployed hosts.                       |
| **Host Config (`nas-pve1`)**    | **Fully Implemented** | NixOS host config for the pve1 instance.                                                       |
| **Host Config (`nas-pve2`)**    | **Fully Implemented** | NixOS host config for the pve2 instance.                                                       |
| **Terraform LXC (`pve1`)**      | **Fully Implemented** | `proxmox_virtual_environment_container` in `containers-pve1.tf`; not yet applied.              |
| **Terraform LXC (`pve2`)**      | **Fully Implemented** | `proxmox_virtual_environment_container` in `containers-pve2.tf`; not yet applied.              |
| **Terraform Template Upload**   | **Fully Implemented** | Provided by the framework (`images-templates.tf`; see the framework spec, §6.1).               |
| **Host Storage Prep (Ansible)** | **Fully Implemented** | `setup_disks` role: pools asserted, datasets and Samba state dir converged (§11); not yet run. |
| **Host Integration Tests**      | **Fully Implemented** | Auto-discovered tests for `nas-pve1` and `nas-pve2`; passing locally.                          |
| **Flake Registration**          | **Fully Implemented** | Both NAS hosts discovered by the flake (tests and machine matrix).                             |

## 1. Goal

Deploy a NixOS-based LXC container on each Proxmox node (`pve1` and `pve2`) that
exposes host-local ZFS datasets as network file shares over SMB (Samba). The
containers receive ZFS datasets via Proxmox bind mounts, keeping ZFS management
on the host while the container handles only the network-sharing layer.

The general reasons for using a NixOS LXC container (versus a VM) are covered in
the [framework spec](./proxmox-lxc.md#2-rationale); the rationale below is
specific to the NAS workload.

## 2. Rationale

### 2.1 Why One Container Per Node

The Proxmox nodes share neither hardware nor a distributed filesystem. Each has
its own local ZFS pools, with different names, layouts, and capacities (for
example `rpool-sata` on `pve1`, `tank-hdd` on `pve2`). Data lives on whichever
node owns the disks and stays there: there is no shared backend to serve a file
across nodes, and therefore no need for VM-style live migration.

Running one NAS container per node embraces this. Each container serves only its
own host's datasets over bind mounts, with no cross-node storage dependency. The
hardware differences are **host-dependent facts** — pool names, dataset paths,
capacities, and per-node resource sizing — and they live entirely in the
per-node Terraform definitions (§6). The container normalizes them onto uniform
in-container mount points (`/mnt/shared/...`), which is precisely why the NixOS
configuration is identical across nodes even though the storage beneath each one
differs (§5). The container boundary is the adapter that turns heterogeneous,
host-dependent storage into a uniform service — so "host-dependent hardware" and
"identical service config" are not in tension: the former is confined to
Terraform, the latter holds in NixOS.

Concretely, tracing the `media` and `backups` datasets down the stack:

- **Hardware** — differs: `pve1` has SATA SSDs, `pve2` has spinning HDDs.
- **ZFS (host)** — differs: the datasets are mounted at `/rpool-sata/media` and
  `/rpool-sata/backups` on `pve1`, and at `/tank-hdd/media` and
  `/tank-hdd/backups` on `pve2`.
- **Terraform (bind mounts)** — source differs, target is uniform: each node
  binds its own host paths onto the same in-container targets, e.g.
  `/rpool-sata/{media,backups}` → `/mnt/shared/{media,backups}` on `pve1`, and
  `/tank-hdd/{media,backups}` → `/mnt/shared/{media,backups}` on `pve2`.
- **NixOS (service)** — identical for these default datasets: Samba serves
  `/mnt/shared/media` and `/mnt/shared/backups` on both nodes; for the defaults,
  the only difference in the NixOS layer is `networking.hostName` (`nas-pve1` vs
  `nas-pve2`).

The host-dependent values stop at the Terraform bind-mount _source_. Because the
_target_ (`/mnt/shared/...`) is uniform, the NixOS layer has nothing
host-specific left to express beyond the hostname — the one exception being
optional per-host shares, kept small and additive (see
[§5.1](#51-adding-per-host-shares)).

### 2.2 Why Bind Mounts Instead of ZFS-in-Container

Passing raw ZFS device nodes into a container is fragile and requires extensive
privilege escalation. Bind-mounting the pre-mounted dataset paths from the host
is the standard Proxmox pattern: the host manages ZFS (scrubs, snapshots,
replication), and the container sees plain directories.

### 2.3 Why LXC Instead of a VM

The general LXC-versus-VM trade-offs are covered in the
[framework rationale](./proxmox-lxc.md#21-why-lxc-instead-of-a-vm). For this
workload the decisive factor is **avoiding write amplification**. Because the
datasets stay local to each node and never migrate (§2.1), the container gains
nothing from a VM's portability, while a VM would force the file server's data
through a guest filesystem stacked on a virtual disk. The LXC bind mount is a
direct passthrough onto the host ZFS dataset, so Samba writes land on ZFS with
no intermediate filesystem.

The cost is weaker isolation and the UID-mapping handling this requires. That
trade-off is accepted deliberately; see
[Privileged Container](#81-privileged-container).

## 3. Architecture Overview

```text
┌────────────────────────────────────────────────┐
│ Proxmox Host (shown: pve1)                     │
│                                                │
│  ZFS pools ──► /rpool-sata/media               │
│               /rpool-sata/backups              │
│               /rpool-sata/...                  │
│                    │ bind mount                │
│  ┌─────────────────┼─────────────────────────┐ │
│  │ NixOS LXC Container (nas-pveN)            │ │
│  │                 │                         │ │
│  │  /mnt/shared/media ◄──────────────────┘   │ │
│  │  /mnt/shared/backups                      │ │
│  │                                           │ │
│  │  ┌──────────┐                             │ │
│  │  │  Samba   │                             │ │
│  │  │  Server  │                             │ │
│  │  └────┬─────┘                             │ │
│  └───────┼───────────────────────────────────┘ │
│          │                                     │
└──────────┼─────────────────────────────────────┘
           │
      SMB clients
      (Windows, macOS, Linux)
```

The host paths shown are `pve1`'s; on `pve2` the same in-container mount points
are backed by `/tank-hdd/...` instead (see §2.1). Only the bind-mount _source_
changes per node — everything inside the container is identical.

## 4. `nas` Role (`config/nix/roles/nas/default.nix`)

The NAS host imports the framework's `common` role plus the `nas` service role
defined here; `nas` itself imports the framework's
[`proxmox-lxc`](./proxmox-lxc.md#3-proxmox-lxc-role-confignixrolesproxmox-lxcdefaultnix)
role. The `nas` role defines the **default** SMB configuration shared by every
NAS container: the Samba service and its global settings, the default share
definitions (`media` and `backups`), the privileged-container setting the bind
mounts require, and the hostname-management setting GitOps requires. Every node
exposes these defaults identically, so by default only `networking.hostName`
differs between hosts; a node that owns extra datasets can layer additional
shares on top in its own `configuration.nix` (see
[§5.1](#51-adding-per-host-shares)).

The role imports `proxmox-lxc` directly because it references the `proxmoxLXC.*`
options that role's module defines; hosts therefore do not import `proxmox-lxc`
themselves.

```nix
{ lib, ... }:

{
  imports = [
    ../proxmox-lxc
  ];

  # Plain values override the proxmox-lxc role's lib.mkDefault defaults;
  # identical for every NAS container.
  proxmoxLXC = {
    # The container is made privileged by Terraform (`unprivileged = false`,
    # section 6.1) so bind-mounted ZFS datasets keep their host UID/GID
    # (host 1000 = container 1000) without an idmap. This option does NOT
    # control that: it only tells the NixOS guest module to expect a
    # privileged environment, and it must agree with the Terraform setting.
    privileged = true;

    # NAS hosts pin networking.hostName: comin selects the configuration by
    # hostname and asserts at build time that it is non-empty. Without this
    # override, the upstream proxmox-lxc module forces networking.hostName
    # to "" (expecting the PVE-written /etc/hostname to provide it), which
    # would fail that assertion. See the note on hostname in the framework
    # spec, section 3.
    manageHostName = true;
  };

  # Samba Server
  services.samba = {
    enable = lib.mkDefault true;
    openFirewall = lib.mkDefault true;

    settings = {
      global = {
        "workgroup" = lib.mkDefault "WORKGROUP";
        "server string" = lib.mkDefault "NixOS NAS";
        "security" = "user";
        "map to guest" = "never";

        # No performance tuning: modern Samba defaults already enable AIO
        # (aio read/write size = 1), and the once-popular tuning knobs
        # interact badly (e.g. a non-zero "aio write size" disables the
        # receivefile path that "min receivefile size" enables). Add tuning
        # only with a benchmark that justifies it.
      };

      # Shares. Every NAS container exposes the same in-container mount points;
      # each node's Terraform bind mounts map its own host datasets onto these
      # paths (see section 6), so this role is identical across nodes.
      "media" = {
        "path" = "/mnt/shared/media";
        "browseable" = "yes";
        "read only" = "no";
        "guest ok" = "no";
        "valid users" = "ferrarimarco";
      };
      "backups" = {
        "path" = "/mnt/shared/backups";
        "browseable" = "yes";
        "read only" = "no";
        "guest ok" = "no";
        "valid users" = "ferrarimarco";
      };
    };
  };
}
```

> **Note on firewall ports:** `services.samba.openFirewall` opens the Samba
> ports automatically (TCP 445 and 139, plus UDP 137 and 138 when `nmbd` is
> enabled), so the `nas` role manages no firewall rules directly.

## 5. Host Configuration

By default, both NAS hosts run an **identical** NixOS configuration, differing
only in `networking.hostName`: the role imports, the privileged-container and
hostname-management settings, and the default Samba shares all live in the
shared roles (chiefly [`nas`](#4-nas-role-confignixrolesnasdefaultnix)). A host
that must serve datasets the others do not can additionally declare
host-specific shares (see [§5.1](#51-adding-per-host-shares)); absent that, each
host's `configuration.nix` sets just the hostname:

```nix
{
  imports = [
    ../../roles/common
    ../../roles/nas
    ../../roles/comin
  ];

  # Required per-host value; a host may also add its own shares (see 5.1).
  networking.hostName = "nas-pve1";
}
```

This matches the `[common, platform role, comin]` import shape used by
[`hl02`](./hl02-proxmox-vm.md); the `nas` role pulls in `proxmox-lxc` itself
(§4).

This works because both nodes expose the **same in-container mount points**
(`/mnt/shared/media`, `/mnt/shared/backups`); each node's Terraform bind mounts
map its own host datasets onto those paths (see §6). The node-specific storage
details therefore live entirely in Terraform, never in the NixOS config. No ZFS
runs inside the container, so no per-host `networking.hostId` is needed either.

As with the [`hl02`](./hl02-proxmox-vm.md) VM, the `comin` role delivers and
maintains this configuration through the pull-based
[GitOps model](./home-lab-bootstrapping.md#35-continuous-deployment-gitops), so
no per-host template is built. comin selects the matching `nixosConfigurations`
output by hostname, which is why the hostname is the one value each host pins.

The configuration deliberately declares no user accounts. All user identity is
centralized in the `common` role, which every host imports. Because the
container is privileged (set in the `nas` role), its UIDs are not shifted: Samba
runs as `ferrarimarco`, and for that to line up with the bind-mounted ZFS
datasets (owned by host UID `1000`) the container's `ferrarimarco` must also be
UID `1000`. The `common` role must therefore pin a stable UID rather than
letting `isNormalUser` auto-allocate one:

```nix
# config/nix/roles/common/default.nix
users.users.ferrarimarco.uid = 1000;
```

The primary group already defaults to `users` (GID `100`), matching the dataset
group ownership. Pinning the UID in `common` keeps it consistent across every
host in the lab, not just the NAS containers.

> **Migration note.** Because `common` is shared, the pin also lands on every
> already-deployed host (e.g. `hl02`). NixOS updates the UID in `/etc/passwd`
> but does not chown existing files. In practice the first `isNormalUser`
> account is auto-allocated UID `1000` anyway, so this should be a no-op —
> verify with `id -u ferrarimarco` on each existing host before landing the pin.

### 5.1 Adding Per-Host Shares

The `media` and `backups` shares are defaults that every NAS container exposes.
A node that owns datasets the others do not (for example a `photos` dataset only
on `pve1`) can serve them by adding a share **on that host only**. A share is
three coupled declarations, so all of them are required:

1. **The host dataset (Ansible).** Add the dataset to that node's `zfs_datasets`
   list in its Ansible `host_vars` (see
   [§11.1](#111-zfs-dataset-mount-points-on-the-host)) so the `setup_disks` role
   creates it and converges its mount-point ownership.
2. **The bind mount (Terraform).** Add the host-path → container-path entry to
   that node's `var.nas_container_bind_mounts` (see
   [§6.2](#62-zfs-dataset-bind-mounts)), for example `/rpool-sata/photos` →
   `/mnt/shared/photos`.
3. **The Samba share (NixOS).** Add the export to that host's
   `configuration.nix`; it merges with the role's defaults:

    ```nix
    # config/nix/hosts/nas-pve1/configuration.nix
    services.samba.settings.photos = {
      "path" = "/mnt/shared/photos";
      "browseable" = "yes";
      "read only" = "no";
      "guest ok" = "no";
      "valid users" = "ferrarimarco";
    };
    ```

> **All three or none.** The declarations are not cross-checked: a Samba share
> without its bind mount exports an empty path, a bind mount without its dataset
> fails to start the container (Proxmox does not create bind-mount sources), and
> a dataset without its share holds data that is never served. Add and remove
> them together.

## 6. Infrastructure Provisioning (Terraform)

The base container resource and template upload follow the
[Terraform provisioning pattern](./proxmox-lxc.md#6-infrastructure-provisioning-terraform)
in the framework spec. The NAS container adds two things on top: the privileged
setting for bind-mount ownership, and the ZFS dataset bind mounts.

### 6.1 Privileged Container

```hcl
  unprivileged = false # Privileged: bind mounts keep host UID/GID (no idmap)
```

A privileged container maps host UID/GID directly (host `1000` = container
`1000`), so the bind-mounted ZFS datasets retain their ownership without an
`lxc.idmap`. This avoids raw LXC config keys (which the `bpg/proxmox` provider
does not expose and would otherwise require a provisioner) at the cost of a
weaker isolation boundary (see §8.1).

> **Keep both sides in agreement.** This Terraform setting is what actually
> makes the container privileged; the `proxmoxLXC.privileged = true` in the
> `nas` role (§4) only tells the NixOS guest module what environment to expect.
> The two are not cross-checked — change them together.

### 6.2 ZFS Dataset Bind Mounts

```hcl
  # Bind mounts for ZFS datasets, parameterized via var.nas_container_bind_mounts
  dynamic "mount_point" {
    for_each = var.nas_container_bind_mounts["pve1"]
    content {
      volume = mount_point.value.host_path
      path   = mount_point.value.container_path
    }
  }

  # Persistent Samba state to survive container recreations
  mount_point {
    volume = "/var/lib/samba-state/nas-pve1"
    path   = "/var/lib/samba"
  }
```

Bind mounts are declared via Terraform variables and dynamically mapped, keeping
dataset details out of the resource block. `/var/lib/samba` is bind-mounted from
host-persistent storage so the Samba password database survives container
recreation (see §7.2). The host-side directory must exist before the container
first starts; see [§11.2](#112-samba-state-directory-on-the-host) for its
prerequisites and backup implications.

## 7. SMB User Management

Samba maintains its own password database (`passdb.tdb`) separate from the Linux
system's `/etc/shadow`. NixOS does not provide a fully declarative mechanism to
populate Samba passwords because storing credentials in the world-readable Nix
store would be a security risk.

### 7.1 Declarative Part

The NixOS configuration declares:

- The system user (`users.users.ferrarimarco`), with its UID pinned to `1000`,
  via the `common` role.
- The Samba share definitions and `valid users` via the `nas` role.
- The Samba service itself (`services.samba.enable = true`).

### 7.2 Imperative Part (One-Time Setup)

After the initial container deployment, the Samba password must be set once
manually, either from the owning Proxmox node:

```bash
# On the Proxmox node that owns the container.
# /bin/sh -lc is required: pct exec does not source a login shell, so
# /run/current-system/sw/bin (where NixOS puts smbpasswd) is not on PATH.
pct exec <vmid> -- /bin/sh -lc 'smbpasswd -a ferrarimarco'
```

or from a shell inside the container:

```bash
sudo smbpasswd -a ferrarimarco
```

This step is intentionally imperative. Because `/var/lib/samba` is mounted from
the host's persistent storage (e.g. `/var/lib/samba-state/nas-pve1`), the Samba
user database (`passdb.tdb`) is preserved across container recreations and
template updates, making it a true one-time setup step for the lifecycle of the
lab. Automating it — without committing secrets, even encrypted ones, to the
public repository — is designed but not implemented; see the Samba password
automation item in [Future Work](#12-future-work).

## 8. Security Considerations

### 8.1 Privileged Container

The container runs privileged so bind-mounted ZFS datasets retain their host
UID/GID without an idmap (see §6.1). This means the container's root user maps
directly to the host's UID 0 inside the container namespace.

Running privileged is a deliberate trade-off, chosen over the alternatives
because they are worse under this lab's constraints: an unprivileged container
with an `lxc.idmap` needs raw LXC config keys the `bpg/proxmox` provider does
not expose (forcing a provisioner this design avoids), and chowning the host
datasets into the shifted UID range makes the data look alien to host-side
tooling (scrubs, snapshots, direct host access). Privileged 1:1 UID mapping
keeps bind-mounted data owned consistently on both sides. The isolation cost is
bounded by the following mitigations:

- The container runs only the Samba service; no user-facing shell access is
  expected.
- SSH is enabled (from the `common` role) but restricted to key-based
  authentication with root login disabled.
- The container has no direct access to ZFS administrative commands; it sees
  bind-mounted directories as plain filesystems.

### 8.2 SMB Security

- Guest access is disabled (`map to guest = never`).
- Only authenticated local users can access shares (`security = user`).
- The Samba password database (`passdb.tdb`, which stores NT password hashes)
  does **not** live in the container's rootfs: `/var/lib/samba` is bind-mounted
  from the host (§6.2), so the hashes reside on the Proxmox host at
  `/var/lib/samba-state/nas-pveN`, readable only by root. Anything that backs up
  that host path captures the hashes; see
  [§11.2](#112-samba-state-directory-on-the-host).

## 9. Integration Testing

### 9.1 Test Auto-Discovery

Both `nas-pve1` and `nas-pve2` contain a `configuration.nix` file and are
automatically discovered by the flake's test generator (see
[Testing Spec - Dynamic Discovery](./declarative-integration-testing.md#33-flake-integration-and-dynamic-test-discovery)).

The auto-generated tests verify:

1. Successful boot (`multi-user.target` reached).
2. SSH port 22 availability.

### 9.2 Samba Coverage in the Test Generator

The Samba service requires bind-mounted share paths that do not exist in the
test VM sandbox. Instead of per-host test overrides, the centralized test
generator (`config/nix/tests/make-test.nix`) handles Samba hosts conditionally,
following the same service-aware pattern it already uses for SSH, the QEMU guest
agent, and comin (see
[Testing Spec - Centralized Test Generator](./declarative-integration-testing.md#32-centralized-test-generator-confignixtestsmake-testnix)):

- It derives the share list from the evaluated `services.samba.settings` (every
  section besides `global` that declares a `path`) and creates each share's path
  as a mock directory via `systemd.tmpfiles` rules.
- It waits for `samba-smbd.service` (NixOS names the Samba units
  `samba-smbd.service`, `samba-nmbd.service`, and so on).
- It asserts that every declared share appears in an anonymous
  (`smbclient -L localhost -N`) enumeration over the null session. This checks
  that the shares are exported, not the authenticated access path, since no
  Samba password can be set declaratively (see section 7).

Because the assertions are derived from the evaluated configuration, a host that
adds a per-host share (section 5.1) is covered automatically: the mock directory
and the enumeration assertion follow the share definition, so the Samba
configuration and its test coverage cannot drift apart.

The NAS hosts therefore ship no `test-override.nix`. The file remains available
for genuinely host-specific assertions (see the framework's
[host structure](./proxmox-lxc.md#4-host-structure)), and the LXC boot tweaks
are applied automatically by the harness (see
[LXC test limitations](./proxmox-lxc.md#7-lxc-specific-test-limitations)).

## 10. Deployment Workflow

### 10.1 Initial Deployment

The examples below use VMID `200` for `nas-pve1`. VMIDs are cluster-unique (the
existing VMs use `100` and `101`), so `nas-pve2` gets its own distinct ID (e.g.
`201`), and each `pct` command runs on the Proxmox node that owns the container.

1. **Converge host storage (Ansible).** The `setup_disks` role (see
   [§11.1](#111-zfs-dataset-mount-points-on-the-host)) asserts that the node's
   ZFS pool exists, creates the `media` and `backups` datasets if missing, sets
   their mount-point ownership, and creates the Samba state directory
   ([§11.2](#112-samba-state-directory-on-the-host)):

    ```bash
    ANSIBLE_PLAYBOOK_FILE_NAME="setup-disks.yaml" \
      ADDITIONAL_ANSIBLE_FLAGS="--limit home_lab_proxmox_nodes" \
      scripts/run-ansible.sh
    ```

2. **Provision the container.** Stage the image artifacts with the
   [`proxmox-images` package](./proxmox-lxc.md#54-artifact-staging-for-terraform-proxmox-images),
   then apply Terraform to upload the generic
   [`nixos-lxc-bootstrap`](./proxmox-lxc.md#5-lxc-template-generation) template
   (shared by every NAS container — no per-host template is built), create the
   container with hostname `nas-pveN` and the ZFS bind mounts, and start it:

    ```bash
    (cd config/nix && nix build .#proxmox-images)
    cd config/terraform/220-proxmox-workloads
    terraform apply
    ```

3. **Hand off to GitOps.** Run the unified bootstrap script from the repository
   root (see the
   [bootstrapping spec](./home-lab-bootstrapping.md#341-unified-bootstrap-entry-point-scriptsbootstrap-hostsh)).
   It discovers the container over SSH, verifies its pinned MAC address, and
   pushes the full host configuration — including `comin` — with
   `nixos-rebuild switch --flake --target-host`; the closure is built on the
   control machine, so the bare bootstrap template needs no flake support or
   PATH setup. Thereafter the container maintains itself from the repository
   (see
   [Continuous Deployment (GitOps)](./home-lab-bootstrapping.md#35-continuous-deployment-gitops)):

    ```bash
    scripts/bootstrap-host.sh nas-pve1 <pinned-mac-address>
    ```

    > **Fallback (no SSH path to the container).** The switch can also run from
    > the owning Proxmox node. Two wrinkles in this variant, both consequences
    > of running against the bare bootstrap template: `pct exec` does not source
    > a login shell (hence `/bin/sh -lc`, since `/run/current-system/sw/bin` is
    > not on its default PATH), and flakes are not enabled until the `common`
    > role lands (hence the `--option` flag):
    >
    > ```bash
    > pct exec 200 -- /bin/sh -lc 'nixos-rebuild switch \
    >   --option extra-experimental-features "nix-command flakes" \
    >   --flake "github:ferrarimarco/home-lab?dir=config/nix#nas-pve1"'
    > ```

4. **Set the Samba password** (one-time, imperative; see
   [§7.2](#72-imperative-part-one-time-setup)):

    ```bash
    pct exec 200 -- /bin/sh -lc 'smbpasswd -a ferrarimarco'
    ```

### 10.2 Configuration Updates

Configuration changes are delivered through GitOps: edit the host
`configuration.nix` (or a shared role) and push to `master`. `comin` polls the
repository on each NAS container and applies the updated
`nixosConfigurations.nas-pveN` closure automatically — no template rebuild,
upload, or container recreation. The Samba password database persists in the
`/var/lib/samba` bind mount across every change.

### 10.3 SMB Clients

Hosts that consume the shares mount them over CIFS. How a client is configured
follows its management layer: Ansible-managed hosts (Debian) declare the mount
as data for the `setup_disks` role; NixOS hosts would declare `fileSystems`
entries (none do yet). The Proxmox nodes mount nothing: each already owns its
datasets natively, and mounting a container's export back onto its own host
would add a network filesystem loop over local data.

The first client is `hl01`, which mounts two `nas-pve1` shares at the mount
points its former local virtual disks occupied, so every consumer keeps its
configured paths:

- the `backups` share at `/media/backup-0` (`workloads_backup_disk_mount_path`),
  replacing the deleted backup virtual disk; the restic backup stack keeps its
  target path.
- the `media-usb` share — the first consumer of a per-host share
  ([§5.1](#51-adding-per-host-shares)), backed by `pve1`'s USB pool — at
  `/media/data0` (`data_disk_mount_path`), replacing the deleted data virtual
  disk. `media_directory_path` (`/media/data0/media`) is unchanged and now
  resolves to a `media/` subdirectory inside the share.

Its `host_vars` declare three pieces, all converged by the `setup_disks` role
(which runs before the node playbook, so the mounts' prerequisites cannot race
it):

- **`mount_os_packages`** — installs `cifs-utils`.
- **`mount_credential_files`** — writes the root-only (`0600`) SMB credentials
  file (`/etc/smb-credentials-nas-pve1`) whose username and password come from
  the shared Ansible vault (`vault_nas_smb_user`, `vault_nas_smb_password` in
  `group_vars/all`, since the credentials may be shared across client hosts),
  keeping the secrets out of the repository consistent with the lab's secrets
  policy. The values are the Samba user and password set in
  [§7.2](#72-imperative-part-one-time-setup).
- **`disks_to_mount`** — the CIFS entries themselves
  (`//nas-pve1.edge.lab.ferrari.how/backups` and
  `//nas-pve1.edge.lab.ferrari.how/media-usb`, sharing the credentials file)
  with
  `credentials=/etc/smb-credentials-nas-pve1,uid=1000,gid=1000,vers=3.1.1,_netdev,nofail`.
  `_netdev` orders the mount after the network is up, and `nofail` keeps the
  client booting when the NAS container is down. The DNS name (backed by a
  router DHCP reservation for the container's pinned MAC, see
  [§11.4](#114-mac-address-pinning)) keeps the source stable across leases.

## 11. Assumptions and Constraints

### 11.1 ZFS Dataset Mount Points on the Host

The Proxmox host must have the ZFS datasets mounted at known, stable paths
(specifically `/rpool-sata/media` and `/rpool-sata/backups` on `pve1` and
`/tank-hdd/media` and `/tank-hdd/backups` on `pve2`), owned by UID `1000`
(`ferrarimarco`) and GID `100` (`users`) to match container permissions.

This layout is codified in Ansible rather than assumed: the
`ferrarimarco_home_lab_setup_disks` role converges it from two per-node
`host_vars` lists, following a read-then-act pattern (query actual state with
`changed_when: false` commands, act only on the delta) instead of the
`community.general.zfs` module, whose property handling is not reliably
idempotent. No suitable Terraform provider exists for ZFS either, which is why
this lives in the Ansible layer that already manages the Proxmox nodes:

- **`zfs_pools` — asserted, never created.** `zpool create` is destructive and
  device-specific, so pool creation stays a deliberate manual act. Each entry
  records the pool's actual topology (`by-id` device paths) and creation options
  (e.g. `ashift`) as executable documentation; the role fails with the
  documented `zpool create` command when the pool is missing.
- **`zfs_datasets` — created if missing** (`zfs create -p`). The declared
  `mount_point` is not an input to ZFS (datasets mount at the ZFS-computed path,
  by default `/<pool>/<dataset>`), so the role then asserts that each dataset's
  actual `mountpoint` property matches the declaration before converging the
  mount point's ownership (UID `1000`, GID `100`) — a drifted declaration fails
  loudly instead of chowning a plain directory that shadows the real dataset.
  The check also works in check mode: datasets that would be created are
  validated against their predicted default mount point, derived from the pool's
  actual one.

The same paths appear as the bind-mount _sources_ in Terraform
(`var.nas_container_bind_mounts`, [§6.2](#62-zfs-dataset-bind-mounts)). The
Ansible and Terraform declarations are two views of the same layout and are not
cross-checked: if a dataset path changes, update both together (and the Samba
share if it is a per-host one; see [§5.1](#51-adding-per-host-shares)).

### 11.2 Samba State Directory on the Host

Each node must provide the persistent directory backing the `/var/lib/samba`
bind mount (`/var/lib/samba-state/nas-pve1` on `pve1`,
`/var/lib/samba-state/nas-pve2` on `pve2`). Proxmox does not create bind-mount
sources, so the directory must exist — owned by `root`, as Samba expects for
`/var/lib/samba` — before the container first starts. Like the datasets
([§11.1](#111-zfs-dataset-mount-points-on-the-host)), this is codified in
Ansible: the directory is declared in each node's `directories_to_create`
`host_vars` list and created by the `setup_disks` role.

As specced, this directory lives on the Proxmox root filesystem, not on the data
pools, so `passdb.tdb` is **not** covered by ZFS snapshots or replication of the
shared datasets; losing it means re-running `smbpasswd` (§7.2), not data loss.
If that trade-off becomes unacceptable, move the directory onto a dedicated ZFS
dataset — and remember that any backup of it captures NT password hashes (see
§8.2).

### 11.3 Networking (DHCP)

The NAS containers use DHCP, consistent with the current approach for
[`hl02`](./hl02-proxmox-vm.md#52-networking-dhcp-for-now). DHCP is requested via
the Terraform `initialization.ip_config` block, which PVE renders into the
container's systemd-networkd configuration (see the framework spec's
[Terraform section](./proxmox-lxc.md#6-infrastructure-provisioning-terraform)).
Static IPs or DHCP reservations should be configured in the router to ensure
stable addressing for SMB clients.

### 11.4 MAC Address Pinning

Each container's network interface is assigned a pinned MAC address in
Terraform, matching the pattern used for VMs. This ensures stable DHCP
reservations.

## 12. Future Work

- **NFS support**: Re-introduce NFS sharing alongside SMB. Evaluate
  `nfs-kernel-server` in a privileged container versus the user-space
  NFS-Ganesha server, which can run in an unprivileged container.
- **Automated template upload**: Replace the local-file push
  (`proxmox_virtual_environment_file` pointing at the local build artifact, per
  the framework pattern — the "Terraform Template Upload" item in the status
  table) with `proxmox_virtual_environment_download_file` pulling the template
  from a published URL, removing the need for a locally built artifact at
  `terraform apply` time.
- **Samba performance tuning**: Benchmark before adding any tuning to the `nas`
  role. Modern Samba enables AIO by default, and the classic knobs interact (a
  non-zero `aio write size` disables `min receivefile size`), so tuning without
  measurement is at best a no-op.
- **GitOps requires the `comin` role per host**: comin needs a hostname at build
  time, so it cannot ride in the shared, hostname-less bootstrap template (see
  [template generation](./proxmox-lxc.md#5-lxc-template-generation)). Each NAS
  host's `configuration.nix` must therefore import the `comin` role itself (see
  §5), which is installed by the one-time `nixos-rebuild switch` handoff in
  §10.1. True zero-touch first-boot GitOps would require working around comin's
  build-time hostname model.
- **Samba password automation**: Replace the imperative `smbpasswd` step (§7.2)
  with a mechanism/material split that keeps secrets out of the public
  repository (committing encrypted secrets — e.g. `sops-nix` ciphertext — was
  considered and rejected: this repository's policy keeps even encrypted secrets
  untracked, and public Git history is immortal). Design: the `nas` role ships a
  oneshot systemd unit that, on every activation, reads a password file from a
  well-known path and pipes it into `smbpasswd -s -a ferrarimarco`; the Ansible
  layer that already manages the Proxmox nodes writes that file (root-only,
  `0600`) to `/var/lib/samba-state/nas-pveN/smb-password` from a vaulted
  (untracked) variable, so the container's existing `/var/lib/samba` bind mount
  delivers it. Container recreation then self-heals the password database,
  rotation is an Ansible run plus a unit restart, and disaster recovery reduces
  to the local Ansible vault, as for every other secret in the lab.
- **SMB service discovery**: Enable Samba's WS-Discovery or Avahi for automatic
  share browsing on Windows and macOS clients.
- **Static IP migration**: Transition from DHCP to static IP assignments defined
  in the NixOS configuration once the network spec is written.
- **Single source of truth for shares**: Derive the Samba share exports (NixOS),
  the bind mounts (Terraform), and the host datasets (Ansible `zfs_datasets`,
  [§11.1](#111-zfs-dataset-mount-points-on-the-host)) from one data structure —
  for example a Nix attrset emitted to `tfvars` via `nix eval` — so each share
  is declared once and the three halves cannot drift (see §5.1).
