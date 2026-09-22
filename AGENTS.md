# AI Agent Instructions & Guidelines

Welcome! This document outlines critical instructions and operational rules that
all AI coding agents must strictly follow when working in the `home-lab`
repository.

## 1. Living Specifications & Documentation Integrity

This repository relies on **living design specifications** to guide all
architectural, testing, and deployment choices before code is modified. These
specs are located in `websites-src/home-lab-docs/specs/`.

### 1.1 Specifications Index & Status Tracking

The specs folder entrypoint
[`websites-src/home-lab-docs/specs/README.md`](./websites-src/home-lab-docs/specs/README.md)
acts as a global index. It features an index table outlining the architectural
scope and overall **Current Implementation Status** of each specification.

### 1.2 Individual Spec Status Tables

Every specification file (e.g., `proxmox-vm.md`, `home-lab-bootstrapping.md`)
contains an **Implementation Status** table right beneath the main title. This
table tracks the status (`Fully Implemented`, `Partially Implemented`, or
`Missing`) of each component defined inside the specification.

### 1.3 Centralized Future Work and TODOs

Future work and todo items are tracked centrally in the "Specifications to write
and TODOs" section of the specs index
[`README.md`](./websites-src/home-lab-docs/specs/README.md), not in per-spec
"Future Work" sections. A spec's "Future Work" section must contain only a
pointer to that centralized list. The list is organized in themed subsections
with a "Current focus" priority list and `Depends on:`/`Blocks:` dependency
annotations: follow the
[Todo list management guide](./websites-src/home-lab-docs/guides/development/todo-list.md)
when adding, completing, or discarding items.

### 1.4 Guides Are the Knowledge Base

Reusable operational and development knowledge (commands, invocation patterns,
troubleshooting workflows, verification recipes) belongs in the guides under
[`websites-src/home-lab-docs/guides/`](./websites-src/home-lab-docs/guides/),
not in this file. When a task produces such knowledge, record the substance in
the relevant guide (creating one if needed) and add at most a brief pointer
here: this file carries rules and pointers, not the knowledge itself.

## 2. Agent Workflow Rules (Crucial)

When executing any task, feature addition, or refactoring inside this codebase,
agents **MUST** adhere to the following documentation workflow:

### Step 1: Discover & Align

Before writing any Nix, Terraform, or CI workflow code, read the relevant design
specifications to understand constraints, design splits, security rules (like
SSH key guards), and naming conventions.

### Step 2: Implement Code

Proceed with the code implementation (writing modules, configs, scripts, or CI
workflows) as approved.

### Step 3: Synchronize Living Status (Mandatory)

As soon as code changes are successfully tested and completed (or when a logical
sub-task is finished), you **MUST** immediately update the status tables in the
documentation to prevent configuration drift:

1.  **Update the Individual Spec Table:** Open the relevant specification file
    in `websites-src/home-lab-docs/specs/` and update the `Status` and `Details`
    fields for the modified features. For example, transition a component from
    `Missing` to `Fully Implemented`.
2.  **Update the Global Index:** Open the specs root
    [`README.md`](./websites-src/home-lab-docs/specs/README.md) and update the
    **Current Implementation Status** column for the target specification to
    reflect the latest state.

To do this, **use the `maintain-living-specs` skill** if available to
programmatically analyze repository changes and systematically synchronize the
individual specification status tables and the root `specs/README.md` index.

## 3. Markdown & Documentation Style Rules

To maintain a highly clean and consistent aesthetic across the documentation,
agents must strictly follow these style rules:

- **No Horizontal Separators:** Do not use `---` horizontal rules or separators
  in any Markdown files. Rely on standard paragraph breaks and clean Markdown
  headers (`##`, `###`) to organize layout.
- **Explicit File References:** Always format file references as Markdown links
  using relative paths (e.g., `[README.md](./README.md)`), ensuring they are
  fully navigable.
- **No Trailing Punctuation in Headings:** Do not place trailing punctuation
  (such as colons `:`, periods `.`, exclamation marks `!`, or question marks
  `?`) at the end of headings. Headings should remain descriptive, clean, and
  concise.

## 4. Operational Scripts

Use the repository's operational scripts for common development and maintenance
tasks instead of ad-hoc commands. The
[operational scripts guide](./websites-src/home-lab-docs/guides/development/operational-scripts.md)
describes them all. Key rules:

- **Tooling via Nix dev shells:** CLI tooling is not installed on the host; it
  comes from the dev shells defined in `config/nix` (`default` and
  `operations`). Invoke tools as
  `nix develop ./config/nix#operations --command <cmd>` from the repository
  root. Terraform is only available in the `operations` shell.
- **Terraform only via `scripts/run-terraform.sh`:** the script performs the
  required environment and local-backend setup and runs `terraform init` before
  applying every numbered stack under `config/terraform/` in sequence. It
  supports `output <service> [<name>]` but has no `validate` path (rely on
  super-linter for static checks). Run it with stdin closed (`</dev/null`) to
  abort instead of hanging on apply-approval prompts, and ask the user before
  any run that contacts the Proxmox API (nodes may be powered off).
- **Terraform state inspection:** each stack's local state lives at
  `config/terraform/environments/backend/local/<service>/terraform.tfstate`;
  reading it (read-only) is the sanctioned way to verify what an apply recorded,
  alongside checks against the real infrastructure. A no-change apply does not
  rewrite the state file, so an old modification time is not evidence that an
  apply failed or was skipped.
- **Image artifact staging:** the `220-proxmox-workloads` Terraform stack reads
  `config/nix/result/iso` and `config/nix/result/tarball`, staged by
  `nix build .#proxmox-images`. Any other `nix build` clobbers the single
  `result` symlink, so re-run that build before applying.
- **Ansible via `scripts/run-ansible.sh`:** runs containerized. Select the
  playbook with `ANSIBLE_PLAYBOOK_FILE_NAME`, pass extra flags (e.g. `--limit`,
  `--check`, `--diff`) via `ADDITIONAL_ANSIBLE_FLAGS`, edit vault files with
  `ANSIBLE_EDIT_VAULT_FILE=true`, and view them read-only with
  `ANSIBLE_VIEW_VAULT_FILE=true` (both take `ANSIBLE_VAULT_FILE_PATH` to select
  a non-default vault file). The script needs the SSH agent socket, which agent
  shells do not inherit: discover it and prefix the invocation with
  `SSH_AUTH_SOCK=<socket>`, as documented in the
  [operational scripts guide](./websites-src/home-lab-docs/guides/development/operational-scripts.md).
  The tag-scoped invocation pattern (stack tag plus `--tags untagged` plus host
  limit) is documented in the
  [operational scripts guide](./websites-src/home-lab-docs/guides/development/operational-scripts.md).
  Always run `--check --diff` first, capture the full output to a log file, and
  review the predictions for unexpected `state: absent` teardowns before
  applying.
- **NixOS integration tests:** every host directory is auto-registered as a
  flake check; run one locally with
  `nix build ./config/nix#checks.x86_64-linux.host-<host>-test --no-link -L`.
  Flakes only see Git-tracked files (`git add` new files first), and `--no-link`
  protects the staged `result` symlink. See the
  [Nix development guide](./websites-src/home-lab-docs/guides/development/nix.md)
  for these and the test-script authoring gotchas.
- **Docs site via `scripts/run-mkdocs.sh`:** rebuild after spec changes and
  commit the regenerated `docs/` output. The script takes required positional
  arguments (a bare invocation fails on an unbound variable); the home-lab docs
  site build is
  `scripts/run-mkdocs.sh build home-lab-docs ./websites-src/home-lab-docs ./docs`.
  The full format-build-lint-commit pipeline for changes under `websites-src/`
  is described in the
  [site development guide](./websites-src/home-lab-docs/guides/development/website-development.md).
- **Linting:** lint and format changes with `scripts/lint.sh`, which runs
  super-linter with the same configuration as CI (set
  `LINTER_CONTAINER_FIX_MODE=true` to apply automatic fixes). Do not hand-roll
  style checks or hand-align Markdown tables: Prettier's fix mode owns
  formatting, including table alignment. Fix mode can report failures against
  pre-fix content, so when it modified files, re-run in check mode for the
  authoritative verdict. To inspect the results, review
  `super-linter-output/super-linter-summary.md` first: it holds the per-linter
  pass/fail table plus the findings of each failed linter. For more detail, read
  the per-linter files under `super-linter-output/super-linter/`. The console
  output is a deep-dive fallback only: it is long, so when running
  `scripts/lint.sh` redirect it in full to a log file; never pipe it through
  `tail` or `head`, which discards the failing linter's message and masks the
  exit code. For targeted formatting while editing, use
  `scripts/format.sh [path ...]` (Prettier, markdownlint, shfmt, textlint, and
  terraform fmt from the same pinned super-linter image); the check-mode
  `scripts/lint.sh` run remains the authoritative verdict. The
  [operational scripts guide](./websites-src/home-lab-docs/guides/development/operational-scripts.md)
  documents these output files and the format script.

## 5. Design & Modularization Rules

When introducing new hosts, roles, or automation features, adhere to these
architectural patterns:

- **Decouple Architecture vs. Deployment:** Never combine global infrastructure
  logic (e.g., how integration testing or bootstrapping works in general) with
  host-specific configuration details. Design modular, reusable specs for the
  framework (under `websites-src/home-lab-docs/specs/`) and keep individual host
  specs focused exclusively on physical/logical declarations for that machine
  (e.g., specific VM core count, dedicated RAM, and MAC address).

## 6. Secrets Policy

- **Nothing secret is ever committed, even encrypted.** Ansible vault files
  (`vault.y*ml*`), Terraform secrets (`*-secrets.tfvars*`), and similar files
  are gitignored by design; committing encrypted ciphertext (e.g. `sops-nix`)
  was considered and rejected because public Git history is immortal.
- Secrets flow through the untracked Ansible vault (host or group scoped) and
  untracked tfvars files; configuration references them via variables (e.g.
  `{{ vault_* }}`).
- Agents cannot edit encrypted vault files. When a new vaulted variable is
  needed, give the user the variable name and the `ANSIBLE_EDIT_VAULT_FILE=true`
  command to add it themselves.
- Agents may verify that a vaulted variable exists without exposing secret
  material by listing key names only, e.g.
  `ANSIBLE_VIEW_VAULT_FILE=true scripts/run-ansible.sh | grep -oE '^vault[a-zA-Z_0-9-]*'`.
  The
  [operational scripts guide](./websites-src/home-lab-docs/guides/development/operational-scripts.md)
  documents the script's vault view mode (neither the host nor the Nix dev
  shells provide `ansible-vault`).
- `--check --diff` output embeds rendered secret-bearing files (vault values
  included). Redirect such logs to the session scratchpad, not the repository,
  and mask secret values when quoting from them.

## 7. Operating on Deployed Hosts

- **Workloads on Debian hosts are Docker Compose services**, with files at
  `/etc/ferrarimarco-home-lab/<service>/compose.yaml` (e.g. `frigate`,
  `media-stack`, `monitoring`, `restic`). Manage lifecycles with
  `docker compose -f <that file> <up -d|stop|restart>`, never raw
  `docker stop/start` on containers.
- **Migrating workloads between hosts follows the
  [container migration guide](./websites-src/home-lab-docs/guides/operations/container-migration.md):**
  inventory flag choreography around a verified data copy. Check target capacity
  and stop the stack before copying its state; do not improvise migrations with
  ad-hoc commands or scripts.
- SSH conventions: `root@pve1`/`root@pve2` for the Proxmox nodes,
  `debian@hl01.edge.lab.ferrari.how` for the hl01 VM,
  `pi@raspberrypi2.edge.lab.ferrari.how` for the raspberrypi2 host. Use
  read-only commands freely for discovery; get approval for state-changing
  commands.
- **The Prometheus backend runs on raspberrypi2** (port 9090, host-local). Query
  it over SSH for historical metrics evidence during incident investigations;
  the
  [unresponsive host runbook](./websites-src/home-lab-docs/guides/troubleshoot-unresponsive-host.md)
  has the query examples and the investigation workflow.
- **Prometheus Alertmanager runs on raspberrypi2** (port 9093, host-local),
  routing alerts to Telegram. Planned host downtime fires availability alerts by
  design: silence it via `amtool` instead of touching the alert rules, as
  documented in the
  [monitoring operations guide](./websites-src/home-lab-docs/guides/operations/monitoring.md).
- **A down Prometheus target is not necessarily an outage:** scrape and probe
  target lists are generated from inventory-wide defaults, so verify the service
  is actually deployed on the target host before treating a down target as a
  service failure, as described in the
  [monitoring operations guide](./websites-src/home-lab-docs/guides/operations/monitoring.md).
- **NixOS LXC containers have no conventional PATH for `pct exec`:** a plain
  `pct exec <vmid> -- <cmd>` fails with "No such file or directory". Invoke
  binaries as `/run/current-system/sw/bin/<cmd>`, or wrap the command in
  `/run/current-system/sw/bin/sh -lc '...'`.
- **pve2 runs 24/7 by user policy, with no HDD spin-down:** never propose or
  configure HDD standby timers (`hdparm -y`/`-S`, ZFS-triggered standby) on
  pve2; the user deliberately keeps platters spinning to avoid start/stop wear.
  Power tuning is limited to levers that do not stop the disks (SATA link power
  management, PCIe ASPM, runtime PM, governor, sysctls).
- **Verify state-changing operations** (Terraform applies, playbook runs,
  bootstrap handoffs) afterward with read-only checks over SSH (`findmnt`,
  `zfs list`, `pct config`, `systemctl is-active`, ...) and report the evidence.

## 8. Ansible Conventions

- **Use the `ansible-developer` skill for any Ansible change:** it carries the
  generic conventions this repository follows (read-then-act for non-idempotent
  modules, assert-don't-automate destructive host state, data-driven roles,
  check-mode friendliness). If the skill is not available, warn the user.
- How the `ferrarimarco_home_lab_node` role's stack, tagging, and enablement
  machinery works is documented in the
  [Ansible development guide](./websites-src/home-lab-docs/guides/development/ansible.md);
  read it before changing the role.
- **Never add role defaults for Debian-conditional enablement flags** (e.g.
  `configure_monitoring_apt`): they are set via `set_fact: ... | default(true)`
  in `register-Debian-facts.yaml`, and a `defaults/main.yaml` entry silently
  pins them and disables the stack.
- **Python exporter services build their venv via the shared `build-python-venv`
  script into a systemd `StateDirectory=`**, never into `/run` or via inline
  `ExecStartPre` venv/pip commands.
