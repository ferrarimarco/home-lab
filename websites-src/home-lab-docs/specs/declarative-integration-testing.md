# Design Spec: Declarative Integration Testing Framework & CI Pipeline

## Implementation Status

| Component / Feature            | Status                | Details                                                           |
| :----------------------------- | :-------------------- | :---------------------------------------------------------------- |
| **Centralized Test Generator** | **Fully Implemented** | Core QEMU framework exists; `specialArgs` mocking implemented.    |
| **Dynamic Flake Discovery**    | **Fully Implemented** | `hostTests` scanning and registration into `checks` exists.       |
| **Optional Host Overrides**    | **Fully Implemented** | Supports an optional `test-override.nix` file for unique asserts. |
| **CI Pipeline Workflow**       | **Fully Implemented** | Multi-job dynamic matrices; machines: `disko.nix` or comin hosts. |

## 1. Goal

Implement a Nix-native integration test framework to verify NixOS host
configurations (system boot, SSH, and QEMU Guest Agent) in isolation, and run
them dynamically and in parallel using a GitHub Actions matrix.

## 2. Rationale

Verifying VM configurations manually or via ad-hoc shell scripts in CI is
brittle and hard to maintain. Transitioning to a declarative testing model using
NixOS's native testing framework (`nixosTest`) ensures that configuration
correctness is verified inside the Nix sandbox, providing reliable and
reproducible feedback. Running these tests in a parallel matrix in CI minimizes
execution time and isolates failures to specific hosts.

## 3. Testing Architecture

### 3.1 Logical vs. Physical Configuration Split

To allow the integration tests to run without triggering physical disk
partitioning (which is handled by Disko and is not suitable for standard
sandboxed NixOS tests), host configurations are split:

- **Logical Configuration (`configuration.nix`):** Contains services (SSH, QEMU
  Guest Agent), hostname, and other logical settings. This is what the
  integration test evaluates.
- **Physical Configuration (`default.nix`):** Imports the logical configuration
  _plus_ hardware definitions (`hardware.nix`) and filesystem layouts
  (`disko.nix`). This is used for actual deployment and full physical builds.

### 3.2 Centralized Test Generator (`config/nix/tests/make-test.nix`)

We utilize a centralized, service-aware NixOS integration test generator.
Individual host subdirectories do not contain individual test wrappers. Instead,
the top-level flake directly invokes this generator, passing the path to the
host's logical `configuration.nix`.

The generator dynamically:

- Sets the test name to `${hostName}-test` by reading the logical configuration.
- Configures the required QEMU `virtio-serial` hardware inside the sandbox if
  `services.qemuGuest` is enabled.
- Constructs the Python test script dynamically based on active services:
    - If `services.openssh` is enabled, it asserts that the SSH daemon
      initializes.
    - If `services.qemuGuest` is enabled, it asserts that
      `/dev/virtio-ports/org.qemu.guest_agent.0` is created and
      `qemu-guest-agent.service` activates.
    - Always asserts that `multi-user.target` is reached (successful boot).
- **Live Attribute Extraction:** Programmatically extracts production-grade
  configuration data (such as `bootstrapPublicKeys`) directly from the evaluated
  package derivation attributes, eliminating the need for loose mock variables.
- **Declarative Cryptographic Auditing:** Leverages `test-override.nix` to
  perform exact filesystem text matching inside the VM, verifying that target
  keys exist perfectly inside the specialized NixOS declarative directory path
  (`/etc/ssh/authorized_keys.d/root`).

### 3.3 Flake Integration and Dynamic Test Discovery

The flake dynamically discovers and registers integration tests for all hosts:

1.  Scans the `./hosts` directory for subdirectories (each representing a host).
2.  Filters out directories that do not contain a `default.nix` file (the same
    marker that registers the host in `nixosConfigurations`).
3.  Checks for an optional `test-override.nix` file within the host directory to
    handle host-specific custom test script assertions or extra configuration
    arguments.
4.  For each valid host, maps the host's logical `configuration.nix` directly
    into `make-test.nix` and formats it as a check attribute:
    `{ name = "host-<host>-test"; value = <test-derivation>; }`.
5.  Exposes these tests in the flake's `checks.${system}` output.

This allows `nix flake check` to automatically run all integration tests
locally. This also achieves a low-maintenance architecture: adding a new host
directory with a `default.nix` automatically flags it for integration testing
locally and in CI.

## 4. GitHub Actions Workflow Update (`.github/workflows/nix.yaml`)

To support scaling the home lab, the CI workflow is split into separate,
optimized jobs:

1.  **`detect-tests` (Discovery):**
    - Queries the flake directly via `nix eval .#checks.x86_64-linux --json` and
      filters keys matching the `host-<host>-test` pattern.
    - Also discovers the machine matrix (deployable hosts; see job 4) and the
      image-package matrix (all entries of `packages.x86_64-linux`).
    - _Benefit:_ Zero-maintenance CI; adding a new host or package automatically
      registers it in CI.

2.  **`static-checks` (Validation):**
    - Runs standard non-test checks, such as code formatting verification
      (`treefmt`).

3.  **`functional-vm-tests` (Parallel Test Execution):**
    - Runs as a matrix job using the output from `detect-tests`.
    - Enables KVM virtualization inside the GitHub Actions runner
      (`enable_kvm: true` in `install-nix-action`).
    - Executes the specific integration test for the matrix target:
        ```bash
        nix build ".#checks.x86_64-linux.host-${MATRIX_HOST}-test" --verbose
        ```
    - _Benefit:_ Isolates test failures to specific hosts and allows parallel
      execution, reducing total CI time.

4.  **`machine-build-tests` (Production Closure Verification):**
    - Builds the production closure
      (`nixosConfigurations.<host>.config.system.build.toplevel`) of every
      **deployable** host. A host qualifies through either marker:
        - it carries a `disko.nix` (deployed via `nixos-anywhere`), or
        - it enables comin (GitOps-managed; LXC containers carry no `disko.nix`,
          so this is what includes them).
    - Fixture hosts (e.g. `minimal-iso`, `minimal-lxc`) match neither marker:
      their `nixosConfigurations` entries have no bootloader or disk
      configuration, so `system.build.toplevel` is not their deployable form.
      What runs on real machines is the image package built from the same module
      set — the installer ISO boots on pristine VMs to install NixOS, and the
      LXC bootstrap tarball is the container template's first boot.
      `package-build-tests` keeps those artifacts buildable, and the VM tests
      exercise their module sets (each fixture's `test-override.nix` imports the
      corresponding package's `modules` passthrough).
        ```bash
        nix build ".#nixosConfigurations.${MATRIX_HOST}.config.system.build.toplevel" --verbose
        ```
    - This job is what surfaces evaluation-time failures in the production
      configuration. The sandboxed VM tests cannot catch them all, because the
      test harness overrides parts of the configuration (for example
      `proxmoxLXC.manageHostName` and the comin remotes), so a module assertion
      such as comin's non-empty-hostname check only fires when the production
      closure itself is evaluated.

5.  **`package-build-tests` (Image Package Verification):**
    - Builds each discovered flake package (the installer ISO and the LXC
      bootstrap template) so deployable images stay buildable.

## 5. Verification Plan

### 5.1 Automated Tests (CI)

- Push a branch to GitHub and verify the multi-job CI pipeline:
    - Verify that `detect-tests` successfully detects all hosts with a
      `default.nix`, plus the image packages.
    - Verify that the `functional-vm-tests` matrix job successfully executes and
      passes the tests in parallel.
    - Verify that the `machine-build-tests` matrix job builds the production
      closure of every deployable host (`disko.nix` or comin-enabled), including
      hosts without a `disko.nix`.
    - Verify that the `package-build-tests` matrix job builds all image
      packages.

### 5.2 Manual Verification (Local/Dev)

- If Nix is available on the development machine and supports KVM, run
  `nix flake check` from `config/nix` to run all discovered integration tests
  locally.
- To run a specific host's test locally:
    ```bash
    nix build .#checks.x86_64-linux.host-<host>-test
    ```
