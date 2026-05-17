# Design Spec: Home Lab Bootstrapping & Installation Infrastructure

## Implementation Status

| Component / Feature    | Status                    | Details                                                        |
| :--------------------- | :------------------------ | :------------------------------------------------------------- |
| **Nix Custom ISO**     | **Missing**               | ISO configuration needs to be added to Flake packages.         |
| **Bootstrap Keys Dir** | **Missing**               | Keys directory needs to be created and staged in Git.          |
| **Security Guardrail** | **Missing**               | Pure-evaluation check to block tracked private keys.           |
| **Operations Shell**   | **Partially Implemented** | Core devshell exists with `terraform`; needs `nixos-anywhere`. |

## 1. Goal

Define a standardized, automated bootstrapping and installation infrastructure
for home lab Virtual Machines using a Nix-native custom installer ISO, secure
bootstrap SSH key management, and `nixos-anywhere` for OS deployment.

## 2. Rationale

Bootstrapping new NixOS hosts manually is tedious and prone to configuration
drift. By declaring a custom installer ISO and automating the installation via
`nixos-anywhere`, we ensure that new hosts can be provisioned from scratch to
their final production state in a single, reproducible workflow.

## 3. Virtual Machine vs. LXC Container Analysis

We deploy home lab workloads as full QEMU Virtual Machines instead of LXC
containers due to the following architectural constraints:

- **Declarative Partitioning:** A VM allows the use of Disko (`disko.nix`) to
  partition the virtual disk natively. LXC containers share the host storage
  directly, rendering Disko incompatible.
- **Bootloader Integrity:** NixOS manages system boot natively via
  `systemd-boot` in a UEFI VM environment. LXC containers bypass the bootloader
  and boot directly from the host kernel, which violates declarative isolation.
- **Health Monitoring:** A VM allows running the standard QEMU Guest Agent
  (`services.qemuGuest` role) for safe shutdowns and backup hooks in Proxmox.

## 4. Bootstrapping Infrastructure

### 4.1 Nix-Native Custom ISO (`config/nix/flake.nix`)

We declare a generic minimal installer ISO in `config/nix/flake.nix`
(`packages.x86_64-linux.installer`) using `nixos-generators`.

- **Root Authorization:** Pre-bakes a dynamic bootstrap public SSH key into the
  `root` user's `authorizedKeys` in the installer ISO. This ensures
  `nixos-anywhere` can authenticate directly as `root` over SSH.
- **Guest Agent Integration:** The installer ISO enables the QEMU Guest Agent
  service (`services.qemuGuest.enable = true;`). This allows Proxmox and
  Terraform to immediately query and report the VM's assigned IP address upon
  its very first boot, ensuring the IP-based fallback remains fully automated.
- **Universal Boot:** This ISO is built once locally (`nix build .#installer`)
  and serves as the universal boot installer for all home lab VMs.

### 4.2 Secure Bootstrap Key Management

To satisfy Nix Flake hermeticity (pure evaluation mode), all bootstrap keys must
be stored inside the flake tree.

- **Directory Structure:** Keys are stored in a dedicated folder at
  `config/nix/ssh-keys/`.
- **Dynamic Key Loading:** The public SSH key is loaded dynamically from
  `config/nix/ssh-keys/home-lab-bootstrap-ssh.pub`. If the file is not present,
  flake evaluation will abort with an explicit error instructing the user on how
  to generate it.
- **Critical Security Guardrail:** The flake must actively protect the private
  key (`config/nix/ssh-keys/home-lab-bootstrap-ssh`) from being accidentally
  staged in Git.
    - _Implementation:_ The flake verifies if
      `builtins.pathExists ./ssh-keys/home-lab-bootstrap-ssh` evaluates to
      `true` (since untracked files are excluded from the sandboxed Nix store in
      pure evaluation mode).
    - _Action:_ If detected in the store, the flake **immediately aborts
      evaluation with a critical security error**, blocking the build or deploy
      process.
    - _Safety:_ The private key must be added to the project's `.gitignore`.

### 4.3 Control Machine Environment (`config/nix/shells/shell-operations.nix`)

To orchestrate the deployment, the control machine's operations shell is
expanded to include:

- `terraform` (for virtual hardware provisioning).
- `nixos-anywhere` (for automated OS installation).

## 5. Bootstrapping & Deployment Workflow

### 5.1 Prerequisites

1.  **Configure Router DHCP Reservation:** Configure a static DHCP reservation
    in your home router mapping the VM's pinned MAC address to a designated IP
    (which will automatically register a DNS record like `<hostname>.<fqdn>`).
2.  **Generate Bootstrap SSH Key:** Create the directory `config/nix/ssh-keys/`,
    generate the SSH key pair inside it, and stage _only_ the public key in Git:
    ```bash
    mkdir -p config/nix/ssh-keys/
    ssh-keygen -t ed25519 -f config/nix/ssh-keys/home-lab-bootstrap-ssh -C "home-lab-bootstrap"
    git add config/nix/ssh-keys/home-lab-bootstrap-ssh.pub
    ```
    _Safety Note:_ Ensure `config/nix/ssh-keys/home-lab-bootstrap-ssh` (the
    private key) is added to the project's `.gitignore` and **never** staged.

### 5.2 Provisioning Steps

1.  **Build the installer ISO:**
    ```bash
    nix build .#installer
    ```
2.  **Provision the hardware (Terraform):**
    ```bash
    nix develop .#operations -c terraform apply
    ```
    _(Terraform creates the VM, uploads the custom ISO, mounts it, and powers on
    the VM. The VM boots the ISO, gets its IP, and registers its DNS)._
3.  **Install the OS (using FQDN DNS with IP fallback):** Attempt to bootstrap
    using the DNS name:
    ```bash
    nix develop .#operations -c nixos-anywhere --flake .#<hostname> root@<hostname>.<fqdn>
    ```
    _DNS Fallback:_ If DNS propagation is delayed or fails, retrieve the IP
    address from the Proxmox UI or Terraform output and run:
    ```bash
    nix develop .#operations -c nixos-anywhere --flake .#<hostname> root@<IP_ADDRESS>
    ```
    _(`nixos-anywhere` connects over SSH, executes Disko to format the drive,
    uploads the production flake closure, installs the bootloader, and reboots
    the VM into the final production state)._
