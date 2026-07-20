# Design Spec: NAS LXC Container for SMB File Sharing

This spec builds on the [NixOS LXC Containers on Proxmox](./proxmox-lxc.md)
framework, which defines the `proxmox-lxc` role, LXC template generation, the
Terraform container-provisioning pattern, and LXC test limitations. This
document covers only the NAS/SMB-specific additions.

## Implementation Status

| Component / Feature           | Status      | Details                                                       |
| :---------------------------- | :---------- | :------------------------------------------------------------ |
| **`nas` Role (SMB)**          | **Missing** | NixOS role enabling Samba with declarative share definitions. |
| **`common` Role UID Pin**     | **Missing** | Pin the `ferrarimarco` UID to `1000` in the `common` role.    |
| **Host Config (`nas-pve1`)**  | **Missing** | NixOS host config for the pve1 instance.                      |
| **Host Config (`nas-pve2`)**  | **Missing** | NixOS host config for the pve2 instance.                      |
| **Terraform LXC (`pve1`)**    | **Missing** | `proxmox_virtual_environment_container` for pve1.             |
| **Terraform LXC (`pve2`)**    | **Missing** | `proxmox_virtual_environment_container` for pve2.             |
| **Terraform Template Upload** | **Missing** | Upload the built LXC template to each node's `local` storage. |
| **Host Integration Tests**    | **Missing** | Auto-discovered tests for `nas-pve1` and `nas-pve2`.          |
| **Flake Registration**        | **Missing** | Verify that both NAS hosts are discovered by the flake.       |

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

Each Proxmox node has its own local ZFS pools (e.g., `rpool-sata` on `pve1`,
`tank-hdd` on `pve2`). Bind-mounting ZFS datasets into a container requires the
datasets to be local to the host kernel. Running one NAS container per node
keeps data locality, avoids cross-node network storage dependencies, and allows
each node to serve its own datasets independently.

### 2.2 Why Bind Mounts Instead of ZFS-in-Container

Passing raw ZFS device nodes into a container is fragile and requires extensive
privilege escalation. Bind-mounting the pre-mounted dataset paths from the host
is the standard Proxmox pattern: the host manages ZFS (scrubs, snapshots,
replication), and the container sees plain directories.

## 3. Architecture Overview

```text
┌────────────────────────────────────────────────┐
│ Proxmox Host (pve1 or pve2)                    │
│                                                │
│  ZFS pools ──► /mnt/tank/media                 │
│               /mnt/tank/backups                │
│               /mnt/tank/...                    │
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

## 4. `nas` Role (`config/nix/roles/nas/default.nix`)

The NAS host imports the `common` and
[`proxmox-lxc`](./proxmox-lxc.md#3-proxmox-lxc-role-confignixrolesproxmox-lxcdefaultnix)
roles from the framework, plus the `nas` service role defined here. The `nas`
role enables SMB file sharing and is protocol-agnostic regarding the specific
shares; each host's `configuration.nix` defines the concrete share paths.

```nix
{ lib, ... }:

{
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

        # Performance tuning for ZFS-backed storage
        "use sendfile" = "yes";
        "min receivefile size" = "16384";
        "aio read size" = "16384";
        "aio write size" = "16384";
      };
    };
  };
}
```

> **Note on firewall ports:** `services.samba.openFirewall` opens the Samba
> ports (TCP 445 and 139) automatically, so the `nas` role manages no firewall
> rules directly.

## 5. Host Configuration

Each NAS host follows the
[LXC host structure](./proxmox-lxc.md#4-host-structure): a `default.nix` entry
point plus a `configuration.nix` that imports the `common`, `proxmox-lxc`,
`nas`, and `comin` roles and defines host-specific share paths. As with the
[`hl02`](./hl02-proxmox-vm.md) VM, the `comin` role delivers and maintains the
configuration through the pull-based
[GitOps model](./home-lab-bootstrapping.md#35-continuous-deployment-gitops), so
no per-host template is built. The `configuration.nix` example below illustrates
the pattern; the actual dataset paths and share names will be defined at
implementation time based on the ZFS datasets present on each node.

```nix
{ lib, ... }:

{
  imports = [
    ../../roles/common
    ../../roles/proxmox-lxc
    ../../roles/nas
    ../../roles/comin
  ];

  networking.hostName = "nas-pve1";
  networking.hostId = "<generated-host-id>";

  # Run privileged so the bind-mounted ZFS datasets keep their host UID/GID
  # (host 1000 = container 1000) without an idmap. The base proxmox-lxc role
  # defaults to unprivileged, so opt in here.
  proxmoxLXC.privileged = lib.mkForce true;

  # No user configuration here: user identity (including the pinned UID that
  # aligns with the host ZFS dataset ownership) is centralized in the common
  # role. See the note below.

  # Samba shares
  services.samba.settings = {
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
}
```

The host `configuration.nix` deliberately declares no user accounts. All user
identity is centralized in the `common` role, which every host imports. Because
the container is privileged, its UIDs are not shifted: Samba runs as
`ferrarimarco`, and for that to line up with the bind-mounted ZFS datasets
(owned by host UID `1000`) the container's `ferrarimarco` must also be UID
`1000`. The `common` role must therefore pin a stable UID rather than letting
`isNormalUser` auto-allocate one:

```nix
# config/nix/roles/common/default.nix
users.users.ferrarimarco.uid = 1000;
```

The primary group already defaults to `users` (GID `100`), matching the dataset
group ownership. Pinning the UID in `common` keeps it consistent across every
host in the lab, not just the NAS containers.

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
recreation (see §7.2).

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
manually:

```bash
# Inside the NAS container
sudo smbpasswd -a ferrarimarco
```

This step is intentionally imperative. Because `/var/lib/samba` is mounted from
the host's persistent storage (e.g. `/var/lib/samba-state/nas-pve1`), the Samba
user database (`passdb.tdb`) is preserved across container recreations and
template updates, making it a true one-time setup step for the lifecycle of the
lab.

## 8. Security Considerations

### 8.1 Privileged Container

The container runs privileged so bind-mounted ZFS datasets retain their host
UID/GID without an idmap (see §6.1). This means the container's root user maps
directly to the host's UID 0 inside the container namespace. Mitigations:

- The container runs only the Samba service; no user-facing shell access is
  expected.
- SSH is enabled (from the `common` role) but restricted to key-based
  authentication with root login disabled.
- The container has no direct access to ZFS administrative commands; it sees
  bind-mounted directories as plain filesystems.

### 8.2 SMB Security

- Guest access is disabled (`map to guest = never`).
- Only authenticated local users can access shares (`security = user`).
- The Samba password database is stored inside the container's rootfs, which is
  backed by ZFS on the host.

## 9. Integration Testing

### 9.1 Test Auto-Discovery

Both `nas-pve1` and `nas-pve2` contain a `configuration.nix` file and are
automatically discovered by the flake's test generator (see
[Testing Spec - Dynamic Discovery](./declarative-integration-testing.md#33-flake-integration-and-dynamic-test-discovery)).

The auto-generated tests verify:

1. Successful boot (`multi-user.target` reached).
2. SSH port 22 availability.

### 9.2 Test Overrides (`test-override.nix`)

Because the Samba service requires bind-mounted paths that do not exist in the
test VM sandbox, each NAS host includes a `test-override.nix` that:

- Creates mock directories for the expected mount points.
- Adds NAS-specific assertions (e.g., verifying that the `smbd` systemd unit is
  active).
- Adds no LXC boot tweaks of its own: the harness applies the
  [LXC test overrides](./proxmox-lxc.md#7-lxc-specific-test-limitations)
  automatically for any host that imports the `proxmox-lxc` role.

```nix
{
  extraConfig = {
    # Create mock mount points so the Samba shares can reference
    # valid paths during the integration test.
    systemd.tmpfiles.rules = [
      "d /mnt/shared/media 0755 root root -"
      "d /mnt/shared/backups 0755 root root -"
    ];
  };

  extraTestScript = ''
    machine.wait_for_unit("smbd.service")
    machine.succeed("smbclient -L localhost -N | grep -q media")
  '';
}
```

## 10. Deployment Workflow

### 10.1 Initial Deployment

1. **Provision the container.** Apply Terraform to upload the generic
   [`nixos-lxc-bootstrap`](./proxmox-lxc.md#5-lxc-template-generation) template
   (shared by every NAS container — no per-host template is built), create the
   container with hostname `nas-pveN` and the ZFS bind mounts, and start it:

    ```bash
    cd config/terraform/220-proxmox-workloads
    terraform apply
    ```

2. **Hand off to GitOps.** Apply the host configuration once to install `comin`;
   thereafter the container maintains itself from the repository (see
   [Continuous Deployment (GitOps)](./home-lab-bootstrapping.md#35-continuous-deployment-gitops)):

    ```bash
    pct exec 200 -- nixos-rebuild switch \
      --flake "github:ferrarimarco/home-lab?dir=config/nix#nas-pve1"
    ```

3. **Set the Samba password** (one-time, imperative):

    ```bash
    pct exec 200 -- smbpasswd -a ferrarimarco
    ```

### 10.2 Configuration Updates

Configuration changes are delivered through GitOps: edit the host
`configuration.nix` (or a shared role) and push to `master`. `comin` polls the
repository on each NAS container and applies the updated
`nixosConfigurations.nas-pveN` closure automatically — no template rebuild,
upload, or container recreation. The Samba password database persists in the
`/var/lib/samba` bind mount across every change.

## 11. Assumptions and Constraints

### 11.1 ZFS Dataset Mount Points on the Host

The Proxmox host must have the ZFS datasets mounted at known, stable paths
(specifically `/rpool-sata/media` and `/rpool-sata/backups` on `pve1` and
`/tank-hdd/media` and `/tank-hdd/backups` on `pve2`). The host directories must
be owned by UID `1000` (`ferrarimarco`) to match container permissions.

The mount points are parameterized in Terraform using input variable maps to
prevent hardcoding host paths inside the container configurations. If ZFS
dataset paths change, the Terraform parameters must be updated to match the new
host paths.

### 11.2 Networking (DHCP)

The NAS containers use DHCP, consistent with the current approach for
[`hl02`](./hl02-proxmox-vm.md#52-networking-dhcp-for-now). Static IPs or DHCP
reservations should be configured in the router to ensure stable addressing for
SMB clients.

### 11.3 MAC Address Pinning

Each container's network interface is assigned a pinned MAC address in
Terraform, matching the pattern used for VMs. This ensures stable DHCP
reservations.

## 12. Future Work

- **NFS support**: Re-introduce NFS sharing alongside SMB. Evaluate
  `nfs-kernel-server` in a privileged container versus the user-space
  NFS-Ganesha server, which can run in an unprivileged container.
- **Automated template upload**: Use Terraform's
  `proxmox_virtual_environment_download_file` to automate template uploads to
  Proxmox storage.
- **GitOps requires the `comin` role per host**: comin needs a hostname at build
  time, so it cannot ride in the shared, hostname-less bootstrap template (see
  [template generation](./proxmox-lxc.md#5-lxc-template-generation)). Each NAS
  host's `configuration.nix` must therefore import the `comin` role itself (see
  §5), which is installed by the one-time `nixos-rebuild switch` handoff in
  §10.1. True zero-touch first-boot GitOps would require working around comin's
  build-time hostname model.
- **Samba password automation**: Explore `sops-nix` or similar secret management
  to populate Samba passwords declaratively via activation scripts.
- **SMB service discovery**: Enable Samba's WS-Discovery or Avahi for automatic
  share browsing on Windows and macOS clients.
- **Static IP migration**: Transition from DHCP to static IP assignments defined
  in the NixOS configuration once the network spec is written.
- **ZFS dataset Terraform management**: Define the ZFS datasets themselves in
  Terraform or a separate Nix module for full declarative coverage.
