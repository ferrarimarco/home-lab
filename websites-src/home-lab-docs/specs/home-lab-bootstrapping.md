# Design Spec: Home Lab Bootstrapping and Installation Infrastructure

## Implementation Status

| Component / Feature    | Status                | Details                                                          |
| :--------------------- | :-------------------- | :--------------------------------------------------------------- |
| **Nix Custom ISO**     | **Fully Implemented** | Custom nixos-installer ISO configured with the proxmox-vm role.  |
| **Bootstrap Keys Dir** | **Fully Implemented** | Keys directory created and staged in Git (private key ignored).  |
| **Security Guardrail** | **Fully Implemented** | Pure-evaluation check blocks tracked private keys in flake.nix.  |
| **Operations Shell**   | **Fully Implemented** | Operations shell includes both `terraform` and `nixos-anywhere`. |

## 1. Goal

Define a standardized, automated bootstrapping and installation infrastructure
for home lab Virtual Machines using a Nix-native custom installer ISO, secure
bootstrap SSH key management, and `nixos-anywhere` for OS deployment.

## 2. Rationale

Bootstrapping new NixOS hosts manually is tedious and prone to configuration
drift. By declaring a custom installer ISO and automating the installation via
`nixos-anywhere`, we ensure that new hosts can be provisioned from scratch to
their final production state in a single, reproducible workflow.

## 3. Bootstrapping Infrastructure

### 3.1 Nix-Native Custom ISO (`config/nix/packages/nixos-installer.nix`)

We declare a generic minimal installer ISO in
`config/nix/packages/nixos-installer.nix` and register it in
`config/nix/flake.nix` as `packages.x86_64-linux.nixos-installer` using
`nixos-generators`.

- **Root Authorization:** Pre-bakes a dynamic bootstrap public SSH key into the
  `root` user's `authorizedKeys` in the installer ISO. This ensures
  `nixos-anywhere` can authenticate directly as `root` over SSH.
- **Guest Agent Integration:** The installer ISO imports the shared `proxmox-vm`
  role to enable the QEMU Guest Agent service
  (`services.qemuGuest.enable = true`). This allows Proxmox and Terraform to
  immediately query and report the VM's assigned IP address upon its very first
  boot, ensuring the IP-based fallback remains fully automated.
- **Universal Boot:** This ISO is built once locally
  (`nix build .#nixos-installer`) and serves as the universal boot installer for
  all home lab VMs.

### 3.2 Secure Bootstrap Key Management

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

### 3.3 Control Machine Environment (`config/nix/shells/shell-operations.nix`)

To orchestrate the deployment, the control machine's operations shell is
expanded to include:

- `terraform` (for virtual hardware provisioning).
- `nixos-anywhere` (for automated OS installation).
