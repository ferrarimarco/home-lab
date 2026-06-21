# Design Spec: Home Lab Bootstrapping and Installation Infrastructure

## Implementation Status

| Component / Feature                         | Status                | Details                                                                                         |
| :------------------------------------------ | :-------------------- | :---------------------------------------------------------------------------------------------- |
| **Nix Custom ISO**                          | **Fully Implemented** | Custom nixos-installer ISO configured with the proxmox-vm role.                                 |
| **Bootstrap Keys Dir**                      | **Fully Implemented** | Keys directory created and staged in Git (private key ignored).                                 |
| **Security Guardrail**                      | **Fully Implemented** | Pure-evaluation check blocks tracked private keys in flake.nix.                                 |
| **Operations Shell**                        | **Fully Implemented** | Operations shell includes both `terraform` and `nixos-anywhere`.                                |
| **Provisioning and installation lifecycle** | **Fully Implemented** | Operational choreography and automated handoff sequence defined but pending automation scripts. |
| **GitOps CD (Comin)**                       | **Not Implemented**   | Pull-based continuous deployment for Day-2 state management.                                    |

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
`config/nix/flake.nix` as `packages.x86_64-linux.nixos-installer` using the
built-in NixOS `system.build.isoImage` derivation pipeline.

- **Root Authorization:** Pre-bakes the declarative `bootstrapPublicKeys` array
  directly into the `root` user's `authorizedKeys` in the installer ISO. This
  ensures `nixos-anywhere` can authenticate directly as `root` over SSH.
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
- **Dynamic Key Loading:** The public SSH key is loaded dynamically from the
  keys directory array inputs. If required public keys are missing, flake
  evaluation will abort with an explicit error instructing the user on how to
  generate it.
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

### 3.4 Provisioning and Installation Lifecycle

The execution workflow transitions from a stateless installer environment to an
immutable, disk-backed production machine via the following sequential phases:

1. **Initialization and Phoning Home:** The virtual machine boots the custom
   ISO. The embedded `qemu-guest-agent` starts and broadcasts the VM's dynamic
   IP address to the Proxmox VE API, which is consumed by the local control
   machine.
2. **Secure SSH Access:** The control machine invokes `nixos-anywhere` utilizing
   the local private bootstrap key. The live ISO authenticates the session via
   its pre-baked `bootstrapPublicKeys` array.
3. **Declarative Partitioning:** `nixos-anywhere` delivers the host's
   `disko.nix` schema to the target and executes it. Disko wipes the physical
   disk layout, builds partitions, creates filesystems, and mounts the root
   structure to `/mnt`.
4. **Closure Synchronisation:** The control machine evaluates and compiles the
   host's physical production top-level configuration. The complete operating
   system closure is copied directly over the encrypted SSH tunnel into
   `/mnt/nix/store`.
5. **Boot Execution Handoff:** `nixos-anywhere` initializes `nixos-install` to
   register the primary bootloader inside the hardware's EFI system partition,
   then issues an un-graceful `reboot`. The VM power-cycles, discards the
   temporary ISO environment, and boots natively into its final production
   state.
6. **Day 2 Operations (GitOps):** Upon booting into the final production state,
   the `comin` service initializes, polls the designated Git repository, and
   continuously applies subsequent configuration updates automatically without
   manual SSH intervention.

### 3.5 Continuous Deployment (GitOps)

Once a machine is bootstrapped, all subsequent state enforcement is shifted to a
pull-based GitOps model to prevent configuration drift and remove the need for
centralized push-based CD pipelines.

- **Comin Integration:** Target physical configurations include the `comin`
  module, configured to poll the primary Git repository.
- **Authentication:** (If using a private repo) An authenticating deploy key or
  token must be provisioned during the `nixos-anywhere` handoff via the
  `--extra-files` flag, ensuring the newly minted VM has the credentials
  required to pull from the remote immediately on its first boot.
