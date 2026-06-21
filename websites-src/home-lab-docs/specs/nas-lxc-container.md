# Design Spec: NAS LXC Container for NFS and SMB File Sharing

## Implementation Status

| Component / Feature            | Status      | Details                                                       |
| :----------------------------- | :---------- | :------------------------------------------------------------ |
| **NixOS LXC Template Package** | **Missing** | `nixos-generators` `proxmox-lxc` format package.              |
| **`proxmox-lxc` Role**         | **Missing** | NixOS role for LXC-specific base configuration.               |
| **`nas` Role (NFS)**           | **Missing** | NixOS role enabling `nfs-kernel-server` with export config.   |
| **`nas` Role (SMB)**           | **Missing** | NixOS role enabling Samba with declarative share definitions. |
| **Host Config (`nas-pve1`)**   | **Missing** | Logical and physical NixOS host config for the pve1 instance. |
| **Host Config (`nas-pve2`)**   | **Missing** | Logical and physical NixOS host config for the pve2 instance. |
| **Terraform LXC (`pve1`)**     | **Missing** | `proxmox_virtual_environment_container` for pve1.             |
| **Terraform LXC (`pve2`)**     | **Missing** | `proxmox_virtual_environment_container` for pve2.             |
| **Terraform Template Upload**  | **Missing** | `proxmox_virtual_environment_download_file` for LXC template. |
| **Host Integration Tests**     | **Missing** | Auto-discovered tests for `nas-pve1` and `nas-pve2`.          |
| **Flake Registration**         | **Missing** | `nixosConfigurations` entries for both NAS hosts.             |

## 1. Goal

Deploy a NixOS-based LXC container on each Proxmox node (`pve1` and `pve2`) that
exposes host-local ZFS datasets as network file shares over NFS and SMB (Samba).
The containers receive ZFS datasets via Proxmox bind mounts, keeping ZFS
management on the host while the container handles only the network-sharing
layer.

## 2. Rationale

### 2.1 Why LXC Instead of a VM

A full VM for file sharing is wasteful: NFS and SMB are lightweight services
that do not need their own kernel, dedicated disk images, or UEFI firmware. LXC
containers share the host kernel, start in seconds, and consume minimal memory
overhead while still providing process and filesystem isolation.

### 2.2 Why NixOS Inside the Container

The existing infrastructure is fully declarative (NixOS hosts, Nix flake,
Terraform). Using a NixOS LXC container maintains consistency: share
definitions, firewall rules, and user accounts are version-controlled and
reproducible. The same `nixos-generators` tooling already used for the installer
ISO can produce LXC templates.

### 2.3 Why One Container Per Node

Each Proxmox node has its own local ZFS pools (e.g., `rpool-sata` on `pve1`,
`tank-hdd` on `pve2`). Bind-mounting ZFS datasets into a container requires the
datasets to be local to the host kernel. Running one NAS container per node
keeps data locality, avoids cross-node network storage dependencies, and allows
each node to serve its own datasets independently.

### 2.4 Why Bind Mounts Instead of ZFS-in-Container

Passing raw ZFS device nodes into an unprivileged container is fragile and
requires extensive privilege escalation. Bind-mounting the pre-mounted dataset
paths from the host is the standard Proxmox pattern: the host manages ZFS
(scrubs, snapshots, replication), and the container sees plain directories.

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
│  │  ┌──────────┐  ┌──────────┐               │ │
│  │  │ NFS      │  │ Samba    │               │ │
│  │  │ Server   │  │ Server   │               │ │
│  │  └────┬─────┘  └────┬─────┘               │ │
│  └───────┼─────────────┼─────────────────────┘ │
│          │             │                       │
└──────────┼─────────────┼───────────────────────┘
           │             │
      NFS clients    SMB clients
      (Linux, etc.)  (Windows, macOS, etc.)
```

## 4. NixOS Roles

### 4.1 `proxmox-lxc` Role (`config/nix/roles/proxmox-lxc/default.nix`)

A new base role for any NixOS LXC container running on Proxmox, analogous to the
existing [`proxmox-vm`](../../../config/nix/roles/proxmox-vm/default.nix) role.

```nix
{ modulesPath, lib, ... }:

{
  imports = [
    (modulesPath + "/virtualisation/proxmox-lxc.nix")
  ];

  boot.isContainer = true;

  # Suppress systemd units that fail inside LXC
  systemd.suppressedSystemUnits = [
    "dev-mqueue.mount"
    "sys-kernel-debug.mount"
    "sys-fs-fuse-connections.mount"
  ];

  # LXC containers do not use a bootloader
  boot.loader.systemd-boot.enable = lib.mkForce false;
  boot.loader.efi.canTouchEfiVariables = lib.mkForce false;

  networking.useDHCP = lib.mkDefault true;
}
```

### 4.2 `nas` Role (`config/nix/roles/nas/default.nix`)

A service role that enables NFS and SMB file sharing. This role is
protocol-agnostic regarding the specific shares; each host's `configuration.nix`
defines the concrete share paths.

```nix
{ lib, ... }:

{
  # NFS Server
  services.nfs.server.enable = lib.mkDefault true;

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

  # NFS firewall ports (NFS v3 and v4)
  networking.firewall.allowedTCPPorts = [
    111   # rpcbind
    2049  # nfsd
    20048 # mountd
  ];
  networking.firewall.allowedUDPPorts = [
    111   # rpcbind
    2049  # nfsd
    20048 # mountd
  ];

  # Lock NFS auxiliary services to fixed ports for firewall predictability
  services.nfs.server.lockdPort = 4001;
  services.nfs.server.mountdPort = 20048;
  services.nfs.server.statdPort = 4002;

  networking.firewall.allowedTCPPorts = [
    4001  # lockd
    4002  # statd
  ];
  networking.firewall.allowedUDPPorts = [
    4001  # lockd
    4002  # statd
  ];
}
```

> **Note on firewall ports:** The `nas` role opens the fixed ports for NFS
> auxiliary daemons (`lockd`, `statd`, `mountd`) to guarantee firewall
> compatibility. NFS v4 strictly requires only port 2049, but v3 clients may
> still use the auxiliary daemons. Samba ports (TCP 445, 139) are opened
> automatically by `services.samba.openFirewall`.

## 5. Host Configurations

### 5.1 Host Structure

LXC containers do not require hardware kernel parameter adjustments, partition
maps (Disko), or bootloader configurations. Because there is no low-level
physical file system or hardware configuration to exclude during sandboxed
integration testing, we do not need the logical/physical split pattern.

Each container's configuration is fully described in a single
`configuration.nix` file:

```text
config/nix/hosts/nas-pve1/
└── configuration.nix    # Container configuration (roles + shares)

config/nix/hosts/nas-pve2/
└── configuration.nix
```

### 5.2 Container Configuration Example (`configuration.nix`)

Each host imports the `common`, `proxmox-lxc`, and `nas` roles, then defines
host-specific share paths and NFS exports. The example below illustrates the
pattern; the actual dataset paths and share names will be defined at
implementation time based on the ZFS datasets present on each node.

```nix
{ ... }:

{
  imports = [
    ../../roles/common
    ../../roles/proxmox-lxc
    ../../roles/nas
  ];

  networking.hostName = "nas-pve1";
  networking.hostId = "<generated-host-id>";

  # Pinned user details to align with host ZFS dataset ownership
  users.users.ferrarimarco = {
    uid = 1000;
    group = "users";
  };
  users.groups.users.gid = 100;

  # NFS exports
  # Each line exports a bind-mounted path to the local subnet.
  # The actual subnet CIDR should match the home network.
  # Forces all_squash to map client requests to the dataset owner UID/GID.
  services.nfs.server.exports = ''
    /mnt/shared/media  192.168.1.0/24(rw,sync,no_subtree_check,all_squash,anonuid=1000,anongid=100)
    /mnt/shared/backups 192.168.1.0/24(rw,sync,no_subtree_check,all_squash,anonuid=1000,anongid=100)
  '';

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

  system.stateVersion = "25.11";
}
```

## 6. NixOS LXC Template Generation

### 6.1 Template Package (`config/nix/packages/nixos-lxc-nas.nix`)

A new flake package produces a `.tar.xz` LXC template using `nixos-generators`
with the `proxmox-lxc` format. This follows the same pattern as the existing
[`nixos-installer`](./home-lab-bootstrapping.md#31-nix-native-custom-iso-confignixpackagesnixos-installernix)
package.

```nix
{
  nixos-generators,
  system,
  inputs,
  bootstrapPublicKey,
  hostConfiguration,
}:

nixos-generators.nixosGenerate {
  inherit system;
  format = "proxmox-lxc";

  modules = [
    hostConfiguration
  ];

  specialArgs = { inherit inputs bootstrapPublicKey; };
}
```

### 6.2 Flake Registration

The flake exposes one template package per NAS host:

```nix
packages.${system} = {
  nixos-installer = import ./packages/nixos-installer.nix { ... };
  nixos-lxc-nas-pve1 = import ./packages/nixos-lxc-nas.nix {
    inherit nixos-generators system inputs bootstrapPublicKey;
    hostConfiguration = ./hosts/nas-pve1/configuration.nix;
  };
  nixos-lxc-nas-pve2 = import ./packages/nixos-lxc-nas.nix {
    inherit nixos-generators system inputs bootstrapPublicKey;
    hostConfiguration = ./hosts/nas-pve2/configuration.nix;
  };
};
```

### 6.3 Build Command

```bash
nix build .#nixos-lxc-nas-pve1
# Output: result/nixos-system-x86_64-linux.tar.xz
```

The resulting tarball is uploaded to each Proxmox node's `local` storage as a
container template using the `proxmox_virtual_environment_file` resource in
Terraform.

## 7. Infrastructure Provisioning (Terraform)

### 7.1 Container Resources

LXC containers are defined in
`config/terraform/220-proxmox-workloads/containers-pveN.tf` using the
`bpg/proxmox` provider's `proxmox_virtual_environment_container` resource.

#### `containers-pve1.tf` (illustrative)

```hcl
# Uploads the built NixOS LXC template to Proxmox
resource "proxmox_virtual_environment_file" "nixos_nas_template_pve1" {
  provider = proxmox.pve1

  content_type = "vztmpl"
  datastore_id = "local"
  node_name    = var.proxmox_virtual_environment_hosts["pve1"].node_name

  source_file {
    path      = "${path.module}/../../../result/tarball/nixos-system-x86_64-linux.tar.xz"
    file_name = "nixos-nas-pve1.tar.xz"
  }
}

resource "proxmox_virtual_environment_container" "nas_pve1" {
  provider = proxmox.pve1

  description  = "Managed by Terraform - NixOS NAS LXC"
  node_name    = var.proxmox_virtual_environment_hosts["pve1"].node_name
  vm_id        = 200
  unprivileged = false  # Required for NFS kernel server
  started      = true

  features {
    nesting = true
    # Enable NFS mount type inside the container
    mount = ["nfs"]
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
    size         = 8  # GB - OS rootfs only, data is bind-mounted
  }

  operating_system {
    template_file_id = proxmox_virtual_environment_file.nixos_nas_template_pve1.id
    type             = "unmanaged"
  }

  # Bind mounts for ZFS datasets
  # Parameterized via var.nas_container_bind_mounts
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

  initialization {
    hostname = "nas-pve1"
  }
}
```

#### Key design decisions

- **`unprivileged = false`**: The NFS kernel server requires a privileged
  container to interact with the host kernel's NFS modules (`nfsd`,
  `rpc_pipefs`). This is a deliberate security trade-off documented in
  section 9.
- **`type = "unmanaged"`**: Prevents Proxmox from running OS-specific
  configuration hooks (e.g., Debian `cloud-init`) that are incompatible with
  NixOS.
- **`features.nesting = true`**: Required for NixOS `systemd` to function
  correctly inside LXC.
- **`features.mount = ["nfs"]`**: Permits the container to mount NFS filesystems
  (if needed for cross-container access in the future).
- **Small OS disk**: The rootfs only needs enough space for the NixOS system
  closure. All user data resides on bind-mounted ZFS datasets.
- **Bind mount parameterization**: Mounts are declared via standard Terraform
  variables and dynamically mapped, keeping dataset details out of the core
  resource block.
- **Declarative template upload**: The template is uploaded using the
  `proxmox_virtual_environment_file` resource, creating a direct dependency via
  `template_file_id` that guarantees the template is uploaded before container
  creation.

### 7.2 AppArmor Configuration & Automation

Running `nfs-kernel-server` inside a privileged LXC requires relaxing the
default AppArmor profile by appending `lxc.apparmor.profile: unconfined` to the
Proxmox host's configuration file `/etc/pve/lxc/<vmid>.conf`.

Because the `bpg/proxmox` Terraform provider does not natively expose raw LXC
config keys like `lxc.apparmor.profile`, we automate this post-creation tweak
using a Terraform `remote-exec` provisioner directly on the container resource:

```hcl
  provisioner "remote-exec" {
    inline = [
      "echo 'lxc.apparmor.profile: unconfined' >> /etc/pve/lxc/${self.vm_id}.conf",
      "pct restart ${self.vm_id}"
    ]

    connection {
      type     = "ssh"
      user     = "root"
      password = var.proxmox_virtual_environment_hosts_secrets["pve1"].password
      host     = split(":", split("//", var.proxmox_virtual_environment_hosts["pve1"].api_endpoint)[1])[0]
    }
  }
```

A custom AppArmor profile that only permits `mount fstype=nfsd` is a more secure
alternative and is recommended for production hardening in a follow-up
iteration.

### 7.3 Container ID Allocation

Following the existing numbering convention (VMs start at 100), LXC containers
use a separate range starting at 200:

| Container ID | Host     | Node |
| :----------- | :------- | :--- |
| 200          | nas-pve1 | pve1 |
| 201          | nas-pve2 | pve2 |

## 8. SMB User Management

Samba maintains its own password database (`passdb.tdb`) separate from the Linux
system's `/etc/shadow`. NixOS does not provide a fully declarative mechanism to
populate Samba passwords because storing credentials in the world-readable Nix
store would be a security risk.

### 8.1 Declarative Part

The NixOS configuration declares:

- The system user (`users.users.ferrarimarco`) via the `common` role.
- The Samba share definitions and `valid users` via the `nas` role.
- The Samba service itself (`services.samba.enable = true`).

### 8.2 Imperative Part (One-Time Setup)

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

## 9. Security Considerations

### 9.1 Privileged Container

The NFS kernel server requires a privileged container. This means the
container's root user maps directly to the host's UID 0 inside the container
namespace. Mitigations:

- The container runs only NFS and SMB services; no user-facing shell access is
  expected.
- SSH is enabled (from the `common` role) but restricted to key-based
  authentication with root login disabled.
- The container has no direct access to ZFS administrative commands; it sees
  bind-mounted directories as plain filesystems.

### 9.2 NFS Security

- Exports are restricted to the local subnet CIDR (e.g., `192.168.1.0/24`).
- `no_root_squash` is used only where explicitly required (e.g., for backup
  agents that need root-level file access). All other exports should use the
  default `root_squash`.
- NFSv4 is preferred over NFSv3 when clients support it, as it requires only a
  single port (2049) and supports stronger authentication.

### 9.3 SMB Security

- Guest access is disabled (`map to guest = never`).
- Only authenticated local users can access shares (`security = user`).
- The Samba password database is stored inside the container's rootfs, which is
  backed by ZFS on the host.

### 9.4 AppArmor

The initial deployment uses `lxc.apparmor.profile: unconfined` for simplicity. A
follow-up hardening task should create a minimal custom AppArmor profile that
permits only the NFS-related mount operations (`mount fstype=nfsd`,
`mount fstype=nfs`, `mount fstype=rpc_pipefs`).

## 10. Integration Testing

### 10.1 Test Auto-Discovery

Both `nas-pve1` and `nas-pve2` contain a `configuration.nix` file and are
automatically discovered by the flake's test generator (see
[Testing Spec - Dynamic Discovery](./declarative-integration-testing.md#33-flake-integration-and-dynamic-test-discovery)).

The auto-generated tests verify:

1. Successful boot (`multi-user.target` reached).
2. SSH port 22 availability.

### 10.2 Test Overrides (`test-override.nix`)

Because NFS and SMB services require bind-mounted paths that do not exist in the
test VM sandbox, each NAS host includes a `test-override.nix` that:

- Creates mock directories for the expected mount points.
- Adds NAS-specific assertions (e.g., verifying that `smbd` and `nfsd` systemd
  units are active).

```nix
{
  extraConfig = {
    # Create mock mount points so NFS exports and Samba shares
    # can reference valid paths during the integration test.
    systemd.tmpfiles.rules = [
      "d /mnt/shared/media 0755 root root -"
      "d /mnt/shared/backups 0755 root root -"
    ];
  };

  extraTestScript = ''
    machine.wait_for_unit("smbd.service")
    machine.wait_for_unit("nfs-server.service")
    machine.succeed("smbclient -L localhost -N | grep -q media")
  '';
}
```

### 10.3 LXC-Specific Test Limitations

The standard NixOS test framework runs tests inside QEMU VMs, not LXC
containers. This means:

- The `proxmox-lxc` module's LXC-specific settings (e.g., `boot.isContainer`)
  must be overridden in the test environment to avoid conflicts with the
  QEMU-based test runner.
- The `test-override.nix` should include `boot.isContainer = lib.mkForce false;`
  to allow the test VM to boot normally.

## 11. Deployment Workflow

### 11.1 Initial Deployment

1. **Build the LXC template:**
    ```bash
    nix build .#nixos-lxc-nas-pve1
    ```
2. **Apply Terraform:**

    ```bash
    cd config/terraform/220-proxmox-workloads
    terraform apply
    ```

    (Note: Terraform automatically uploads the NixOS LXC template tarball using
    the `proxmox_virtual_environment_file` resource, configures the container,
    executes the AppArmor tweaks via the `remote-exec` provisioner, and restarts
    the container.)

3. **Post-deploy: Set Samba password** (imperative, inside the container):
    ```bash
    pct exec 200 -- smbpasswd -a ferrarimarco
    ```

### 11.2 Configuration Updates

To update the NAS configuration after changing `configuration.nix`:

1. Rebuild the LXC template: `nix build .#nixos-lxc-nas-pve1`
2. Upload and replace the template on Proxmox.
3. Recreate the container from the new template via Terraform. This is safe to
   run since the container rootfs is stateless; the Samba password database is
   stored in the `/var/lib/samba` bind mount which persists on the host.
   Alternatively, SSH into the running container and run `nixos-rebuild switch`
   if the flake is available inside the container.

## 12. Assumptions and Constraints

### 12.1 ZFS Dataset Mount Points on the Host

The Proxmox host must have the ZFS datasets mounted at known, stable paths
(specifically `/rpool-sata/media` and `/rpool-sata/backups` on `pve1` and
`/tank-hdd/media` and `/tank-hdd/backups` on `pve2`). The host directories must
be owned by UID `1000` (`ferrarimarco`) to match container permissions.

The mount points are parameterized in Terraform using input variable maps to
prevent hardcoding host paths inside the container configurations. If ZFS
dataset paths change, the Terraform parameters must be updated to match the new
host paths.

### 12.2 Networking (DHCP)

The NAS containers use DHCP, consistent with the current approach for
[`hl02`](./hl02-proxmox-vm.md#52-networking-dhcp-for-now). Static IPs or DHCP
reservations should be configured in the router to ensure stable addressing for
NFS/SMB clients.

### 12.3 MAC Address Pinning

Each container's network interface is assigned a pinned MAC address in
Terraform, matching the pattern used for VMs. This ensures stable DHCP
reservations.

### 12.4 Terraform Provider Authentication

Bind mounts in the `bpg/proxmox` provider require authentication as `root@pam`.
The existing provider configuration already supports username/password
authentication alongside API tokens.

### 12.5 NFS-Ganesha as an Alternative

If the privileged container requirement for `nfs-kernel-server` proves too
restrictive, NFS-Ganesha (a user-space NFS server) is a viable alternative that
can run inside an unprivileged container. This would require replacing
`services.nfs.server` with a custom NFS-Ganesha NixOS module. This trade-off
should be evaluated during implementation.

## 13. Future Work

- **Custom AppArmor profile**: Replace `unconfined` with a minimal profile that
  permits only NFS-related kernel operations.
- **Automated template upload**: Use Terraform's
  `proxmox_virtual_environment_download_file` or a provisioner to automate
  template uploads to Proxmox storage.
- **Samba password automation**: Explore `sops-nix` or similar secret management
  to populate Samba passwords declaratively via activation scripts.
- **SMB service discovery**: Enable Samba's WS-Discovery or Avahi for automatic
  share browsing on Windows and macOS clients.
- **Static IP migration**: Transition from DHCP to static IP assignments defined
  in the NixOS configuration once the network spec is written.
- **ZFS dataset Terraform management**: Define the ZFS datasets themselves in
  Terraform or a separate Nix module for full declarative coverage.
