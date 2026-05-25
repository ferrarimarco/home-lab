# Design Spec: Declarative Integration Testing Framework & CI Pipeline

## Implementation Status

| Component / Feature            | Status                    | Details                                                           |
| :----------------------------- | :------------------------ | :---------------------------------------------------------------- |
| **Centralized Test Generator** | **Partially Implemented** | Core QEMU framework exists; needs `specialArgs` mocking.          |
| **Dynamic Flake Discovery**    | **Fully Implemented**     | `hostTests` scanning and registration into `checks` exists.       |
| **Optional Host Overrides**    | **Fully Implemented**     | Supports an optional `test-override.nix` file for unique asserts. |
| **CI Pipeline Workflow**       | **Missing**               | Needs multi-job dynamic matrix configuration.                     |

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
    - If `services.openssh` is enabled, it asserts that SSH port 22 opens.
    - If `services.qemuGuest` is enabled, it asserts that
      `/dev/virtio-ports/org.qemu.guest_agent.0` is created and
      `qemu-guest-agent.service` activates.
    - Always asserts that `multi-user.target` is reached (successful boot).
- **Mocks `specialArgs` Dependencies:** Automatically injects mock values for
  required `specialArgs` (such as a dummy bootstrap SSH public key) to allow the
  logical configuration to evaluate in isolation.
- **Runtime Overrides:** Includes comments and documentation within the
  generator instructing developers on how to override these mock values with
  real keys or custom configurations at runtime if needed for advanced
  validation.

### 3.3 Flake Integration and Dynamic Test Discovery

The flake dynamically discovers and registers integration tests for all hosts:

1.  Scans the `./hosts` directory for subdirectories (each representing a host).
2.  Filters out directories that do not contain a `configuration.nix` file.
3.  Checks for an optional `test-override.nix` file within the host directory to
    handle host-specific custom test script assertions or extra configuration
    arguments.
4.  For each valid host, maps the host configuration directly into
    `make-test.nix` and formats it as a check attribute:
    `{ name = "<hostname>-test"; value = <test-derivation>; }`.
5.  Exposes these tests in the flake's `checks.${system}` output.

This allows `nix flake check` to automatically run all integration tests
locally. This also achieves a low-maintenance architecture: adding a
`configuration.nix` to a new host directory automatically flags it for
integration testing locally and in CI.

## 4. GitHub Actions Workflow Update (`.github/workflows/nix.yaml`)

To support scaling the home lab, the CI workflow is split into separate,
optimized jobs:

1.  **`detect-tests` (Discovery):**
    - Queries the flake directly via `nix eval .#checks.x86_64-linux --json` and
      filters keys ending in `-test`.
    - Outputs a JSON array of hostnames (e.g., `["host1", "host2"]`) to be used
      by the downstream matrix job.
    - _Benefit:_ Zero-maintenance CI; adding a new host with a test
      automatically registers it in CI.

2.  **`static-checks` (Validation):**
    - Runs standard non-test checks, such as code formatting verification
      (`treefmt`).

3.  **`integration-tests` (Parallel Execution):**
    - Runs as a matrix job using the output from `detect-tests`.
    - Enables KVM virtualization inside the GitHub Actions runner
      (`enable_kvm: true` in `install-nix-action`).
    - Executes the specific integration test for the matrix target:
        ```bash
        nix build .#checks.x86_64-linux.${{ matrix.host }}-test --verbose
        ```
    - _Benefit:_ Isolates test failures to specific hosts and allows parallel
      execution, reducing total CI time.

4.  **`build-physical-configs` (Physical Build Verification):**
    - Verifies that the physical configurations (which are excluded from the
      logical integration tests) successfully evaluate and build.
    - Runs as a matrix over all defined hosts in `nixosConfigurations` to ensure
      that the full physical VM images (with Disko) build:
        ```bash
        nix build .#nixosConfigurations.${{ matrix.host }}.config.system.build.toplevel --verbose
        ```

## 5. Verification Plan

### 5.1 Automated Tests (CI)

- Push a branch to GitHub and verify the multi-job CI pipeline:
    - Verify that `detect-tests` successfully dynamically detects all hosts with
      `test.nix`.
    - Verify that the `integration-tests` matrix job successfully executes and
      passes the tests in parallel.
    - Verify that the `build-physical-configs` matrix job successfully performs
      a full build of all physical configurations.

### 5.2 Manual Verification (Local/Dev)

- If Nix is available on the development machine and supports KVM, run
  `nix flake check` from `config/nix` to run all discovered integration tests
  locally.
- To run a specific host's test locally:
    ```bash
    nix build .#checks.x86_64-linux.<hostname>-test
    ```
