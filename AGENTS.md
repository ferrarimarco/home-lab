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

Every specification file (e.g., `hl02-proxmox-vm.md`,
`home-lab-bootstrapping.md`) contains an **Implementation Status** table right
beneath the main title. This table tracks the status (`Fully Implemented`,
`Partially Implemented`, or `Missing`) of each component defined inside the
specification.

### 1.3 Centralized Future Work and TODOs

Future work and todo items are tracked centrally in the "Specifications to write
and TODOs" section of the specs index
[`README.md`](./websites-src/home-lab-docs/specs/README.md), not in per-spec
"Future Work" sections. A spec's "Future Work" section must contain only a
pointer to that centralized list.

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
- **Image artifact staging:** the `220-proxmox-workloads` Terraform stack reads
  `config/nix/result/iso` and `config/nix/result/tarball`, staged by
  `nix build .#proxmox-images`. Any other `nix build` clobbers the single
  `result` symlink, so re-run that build before applying.
- **Ansible via `scripts/run-ansible.sh`:** runs containerized. Select the
  playbook with `ANSIBLE_PLAYBOOK_FILE_NAME`, pass extra flags (e.g. `--limit`,
  `--check`, `--diff`) via `ADDITIONAL_ANSIBLE_FLAGS`, and edit vault files with
  `ANSIBLE_EDIT_VAULT_FILE=true` plus `ANSIBLE_VAULT_FILE_PATH`.
- **Docs site via `scripts/run-mkdocs.sh`:** rebuild after spec changes and
  commit the regenerated `docs/` output.
- **Linting:** lint and format changes with `scripts/lint.sh`, which runs
  super-linter with the same configuration as CI (set
  `LINTER_CONTAINER_FIX_MODE=true` to apply automatic fixes). Do not hand-roll
  style checks or hand-align Markdown tables: Prettier's fix mode owns
  formatting, including table alignment. Fix mode can report failures against
  pre-fix content, so when it modified files, re-run in check mode for the
  authoritative verdict.

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

## 7. Operating on Deployed Hosts

- **Workloads on Debian hosts are Docker Compose services**, with files at
  `/etc/ferrarimarco-home-lab/<service>/compose.yaml` (e.g. `frigate`,
  `media-stack`, `monitoring`, `restic`). Manage lifecycles with
  `docker compose -f <that file> <up -d|stop|restart>`, never raw
  `docker stop/start` on containers.
- SSH conventions: `root@pve1`/`root@pve2` for the Proxmox nodes,
  `debian@hl01.edge.lab.ferrari.how` for the hl01 VM. Use read-only commands
  freely for discovery; get approval for state-changing commands.
- **Verify state-changing operations** (Terraform applies, playbook runs,
  bootstrap handoffs) afterward with read-only checks over SSH (`findmnt`,
  `zfs list`, `pct config`, `systemctl is-active`, ...) and report the evidence.

## 8. Ansible Conventions

- **Read-then-act for non-idempotent modules:** when a module cannot converge
  reliably (e.g. `community.general.zfs` property handling), query actual state
  with commands registered under `changed_when: false` and `check_mode: false`,
  then act only on the delta with guarded CLI tasks.
- **Assert, do not automate, destructive host state:** operations like
  `zpool create` are deliberate manual acts. Record the parameters in inventory
  as executable documentation and `assert` the resource exists, failing with the
  documented creation command.
- **Data-driven roles:** roles consume per-host `host_vars` lists that default
  to empty (no-op on hosts that do not opt in), rather than hardcoding
  host-specific values in tasks.
- **Check-mode friendliness:** design tasks so `--check --diff` runs cleanly and
  truthfully, including on first runs (tolerate reads of resources a previous
  task would have created; validate predicted state instead of skipping).
