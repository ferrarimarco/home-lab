# AI Agent Instructions & Guidelines

Welcome! This document outlines critical instructions and operational rules that
all AI coding agents must strictly follow when working in the `home-lab`
repository.

## 1. Living Specifications & Documentation Integrity

This repository relies on **living design specifications** to guide all
architectural, testing, and deployment choices before code is modified. These
specs are located in `websites-src/home-lab-docs/architecture/`, the
architecture section of the docs site.

### 1.1 Specifications Index & Status Tracking

The architecture section entrypoint
[`websites-src/home-lab-docs/architecture/README.md`](./websites-src/home-lab-docs/architecture/README.md)
acts as a global index. It features an index table outlining the architectural
scope and overall **Current Implementation Status** of each specification.

### 1.2 Individual Spec Status Tables

Every specification file (e.g., `proxmox-vm.md`, `home-lab-bootstrapping.md`)
contains an **Implementation Status** table right beneath the main title; create
it when a specification lacks one. This table tracks the status
(`Fully Implemented`, `Partially Implemented`, or `Missing`) of each component
defined inside the specification. A component is `Fully Implemented` only when
it passes its tests or builds cleanly in CI. The **Status** column tracks
implementation only: when code is implemented but not yet applied to the real
environment, record the pending deployment as a caveat in the **Details** column
(e.g., "not yet applied", "applied on node A; node B not yet run") and remove it
once the deployment is verified, instead of adding deployment values to the
Status column.

### 1.3 Centralized Future Work and TODOs

Future work and todo items are tracked centrally in the "Specifications to write
and TODOs" section of the specs index
[`README.md`](./websites-src/home-lab-docs/architecture/README.md), so they are
never scattered across specifications: a spec carries no "Future Work" section
and no todo items of its own. The list is organized in themed subsections with a
"Current focus" priority list and `Depends on:`/`Blocks:` dependency
annotations: follow the
[Todo list management guide](./websites-src/home-lab-docs/guides/development/todo-list.md)
when adding, completing, or discarding items.

### 1.4 Documentation Placement

[`websites-src/home-lab-docs/architecture/`](./websites-src/home-lab-docs/architecture/)
holds the design and the as-built description of each subsystem: a page with a
status table is a specification, and its status table, not a separate section,
tells design from reality. Reference pages (software candidates, references) sit
beside the specifications with no status table and no row in the specifications
index table, and the index lists them. Forward-looking material, intentions
included, goes in the todo list of the index, not in a page that reads as a
description of the lab; procedures go in the guides.

### 1.5 Guides Are the Knowledge Base

Reusable operational and development knowledge (commands, invocation patterns,
troubleshooting workflows, verification recipes) belongs in the guides under
[`websites-src/home-lab-docs/guides/`](./websites-src/home-lab-docs/guides/),
not in this file. When a task produces such knowledge, record the substance in
the relevant guide (creating one if needed) and add at most a brief pointer
here: this file carries rules and pointers, not the knowledge itself. Each fact
has one home: a new page links to where a fact already lives (the backups
specification holds the verification matrix, the operations guide the recipes)
instead of restating it, and overlap between pages is removed rather than
reworded.

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
    in `websites-src/home-lab-docs/architecture/` and update the `Status` and
    `Details` fields for the modified features, with precise, objective details
    (e.g., "MAC declared in Terraform; awaiting test verification"). For
    example, transition a component from `Missing` to `Fully Implemented`.
2.  **Update the Global Index:** Open the specs root
    [`README.md`](./websites-src/home-lab-docs/architecture/README.md) and
    update the **Current Implementation Status** column for the target
    specification to reflect the latest state.

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
- **No Private Identifiers:** Do not put private or personal identifiers
  (people's names, personal directory or share names) in committed
  documentation; describe them neutrally (for example "a personal data
  directory").

## 4. Operational Scripts

Use the repository's operational scripts for common development and maintenance
tasks instead of ad-hoc commands. The
[operational scripts guide](./websites-src/home-lab-docs/guides/development/operational-scripts.md)
describes them all. Key rules:

- **Tooling via Nix dev shells:** CLI tooling is not installed on the host; it
  comes from the dev shells defined in `config/nix` (`default` and
  `operations`). Invoke tools as
  `nix develop ./config/nix#operations --command <cmd>` from the repository
  root. The
  [Nix development shells guide](./websites-src/home-lab-docs/guides/development/nix-dev-shells.md)
  lists the tools in each shell and how to invoke them, including when to use
  the GitHub CLI (`gh`) and which of its subcommands need approval. When
  changing the packages of a shell, update the guide in the same change.
- **Terraform only via `scripts/run-terraform.sh`:** the script performs the
  required environment and local-backend setup and runs `terraform init` before
  applying every numbered stack under `config/terraform/` in sequence. It needs
  `terraform` from the operations dev shell, so invoke it as
  `nix develop ./config/nix#operations --command scripts/run-terraform.sh`. It
  supports `output <service> [<name>]` but has no `validate` path (rely on
  super-linter for static checks). Run it with stdin closed (`</dev/null`) to
  abort instead of hanging on apply-approval prompts, and ask the user before
  any run that contacts the Proxmox API (nodes may be powered off). With stdin
  closed, stacks with no changes complete and the first stack with pending
  changes prints its plan and aborts at the approval prompt: use that as the
  review pass, and supply the approval on a second run only after reviewing the
  plan it printed. The VM resources set `reboot_after_update = false`: an apply
  that needs the guest powered off (a disk resize or move, a TPM device) fails,
  and a change Proxmox holds for the next start (the agent options) succeeds
  with a provider warning and stays pending until a deliberate reboot behind an
  Alertmanager silence, so read the apply output and `qm pending <vmid>` after
  every VM change.
- **Ansible via `scripts/run-ansible.sh`:** runs containerized. Select the
  narrowest playbook under `config/ansible/playbooks/` that covers the change
  (`main.yaml` chains most of the other playbooks, several of whose plays target
  all hosts) with `ANSIBLE_PLAYBOOK_FILE_NAME`, pass extra flags (e.g.
  `--limit`, `--check`, `--diff`) via `ADDITIONAL_ANSIBLE_FLAGS`, edit vault
  files with `ANSIBLE_EDIT_VAULT_FILE=true`, and view them read-only with
  `ANSIBLE_VIEW_VAULT_FILE=true` (both take `ANSIBLE_VAULT_FILE_PATH` to select
  a non-default vault file). The script mounts `config/ansible` of the current
  directory, so a run reads the working tree like the docs build: before an
  apply, check the status for other sessions' changes under that path and, when
  there are any, run from a temporary worktree at the reviewed commit (created
  as the
  [site development guide](./websites-src/home-lab-docs/guides/development/website-development.md)
  describes) by changing into it. The vault password file and the `vault.yaml`
  files are gitignored, so hard-link them (`ln`) into the same paths under the
  worktree's `config/ansible` first, which keeps a single copy of the secret
  material; a hard link needs the worktree on the checkout's filesystem (a
  session scratchpad on the same mount qualifies), so copy them when `ln` fails
  with a cross-device error, and remove them with the worktree. The script needs
  the SSH agent socket, which agent shells do not inherit: discover it and
  prefix the invocation with `SSH_AUTH_SOCK=<socket>`, as documented in the
  [operational scripts guide](./websites-src/home-lab-docs/guides/development/operational-scripts.md).
  The tag-scoped invocation pattern (stack tag plus `--tags untagged` plus host
  limit) is documented in the
  [operational scripts guide](./websites-src/home-lab-docs/guides/development/operational-scripts.md).
  Always run `--check --diff` first, capture the full output to a log file, and
  review the predictions for unexpected `state: absent` teardowns before
  applying.
- **Prometheus alerting rules need a promtool unit test:** every rule in
  `prometheus-alerting-rules.yaml` gets a firing and a non-firing case in
  `test/prometheus-rules/` (one file per rule group); run
  `test/scripts/prometheus-rules-test.sh` before committing, which also fails on
  a rule without a test or without a non-firing case. The
  [operational scripts guide](./websites-src/home-lab-docs/guides/development/operational-scripts.md)
  has the test conventions.
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
  The build reads the working tree, including the uncommitted and untracked
  files of other sessions: before committing generated output, confirm that its
  differences only reflect the sources in the same commit, as the guide
  describes.
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
  `scripts/lint.sh` run remains the authoritative verdict; it rewraps prose and
  re-pads tables, so the global re-read-after-formatting rule applies to every
  run. The
  [operational scripts guide](./websites-src/home-lab-docs/guides/development/operational-scripts.md)
  documents these output files and the format script. Run only one
  `scripts/lint.sh` at a time: concurrent runs clobber the shared
  `super-linter-output/` directory. A lint run can unstage staged changes, so
  stage files after linting, right before committing; a new file is linted only
  once committed (the lint configuration lists `git ls-tree HEAD`), so commit,
  lint, and amend.
- **Validate commit messages before proposing commits:** pipe each proposed
  message to `LINTER_CONTAINER_LINT_COMMIT_MESSAGE=true scripts/lint.sh`, as
  described in the
  [operational scripts guide](./websites-src/home-lab-docs/guides/development/operational-scripts.md).
  A lint run only validates the message of the last commit, while CI validates
  all the pushed commits.
- **Dependency updates:** Dependabot opens the dependency update pull requests,
  configured in `.github/dependabot.yaml`. Read the
  [dependency updates guide](./websites-src/home-lab-docs/guides/operations/dependency-updates.md)
  before changing that file or investigating missing or stuck pull requests.

## 5. Design & Modularization Rules

When introducing new hosts, roles, or automation features, adhere to these
architectural patterns:

- **Decouple Architecture vs. Deployment:** Never combine global infrastructure
  logic (e.g., how integration testing or bootstrapping works in general) with
  host-specific configuration details. Design modular, reusable specs for the
  framework (under `websites-src/home-lab-docs/architecture/`) and keep
  individual host specs focused exclusively on physical/logical declarations for
  that machine (e.g., specific VM core count, dedicated RAM, and MAC address).

- **Only guests that serve other guests declare a Proxmox startup order** (a NAS
  container: `startup { order = 1 }`); consumers of their shares, VMs or
  containers, stay unordered, since Proxmox starts unordered guests after the
  ordered ones. The reference patterns in the
  [LXC](./websites-src/home-lab-docs/architecture/proxmox-lxc.md) and
  [VM](./websites-src/home-lab-docs/architecture/proxmox-vm.md) framework specs
  carry the convention.

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
- **Repository image pins are not what runs until Ansible re-rendered the
  stack:** dependency bumps merged without a playbook run leave hosts on older
  images, and a rendered file may carry hand edits. Read the host's rendered
  compose file or `docker ps` before stating a deployed version, and expect the
  first run after a gap to upgrade every container whose pin changed.
- **Migrating workloads between hosts follows the
  [container migration guide](./websites-src/home-lab-docs/guides/operations/container-migration.md):**
  inventory flag choreography around a verified data copy. Check target capacity
  and stop the stack before copying its state; do not improvise migrations with
  ad-hoc commands or scripts. Cross-host service endpoints (the
  `*_endpoint_fqdn` variables) live in the node role's `vars/main.yaml`, not in
  the inventory: after a move, point them at the new host and re-render the
  monitoring backend on both members of its pair, or the probes keep alerting on
  the old host while the running stack goes unprobed.
- **A container that lists an empty library may hold the bare mount point, not
  the share:** Docker resolves bind sources at container start and a share
  mounted later does not propagate into them. Compare the container's listing
  with the host's and restart the Compose project after the share is mounted, as
  the
  [network share clients guide](./websites-src/home-lab-docs/guides/operations/network-shares.md)
  describes; after a boot with the NAS unreachable the mount retry timer and the
  project units bring them back within minutes of the share returning, and the
  same guide has the checks and the manual steps.
- **Every Compose project has a `docker-compose-up-<project>.service` unit**
  that runs `docker compose up` for it at boot and, for a share-bound project,
  whenever its mount starts; the playbook starts projects through it. A project
  stopped by hand comes back unless its unit is disabled first, as the
  [network share clients guide](./websites-src/home-lab-docs/guides/operations/network-shares.md)
  describes.
- SSH conventions: connect using each host's fully qualified domain name, as
  listed in the Ansible inventory — short hostnames do not resolve from the
  control machine. Connect as `root` to the Proxmox nodes, as `debian` to the
  hl01 VM, and as `pi` to the raspberrypi2 host. Use read-only commands freely
  for discovery; get approval for state-changing commands.
- **Home Assistant state is read from its storage files on hl01** (entity and
  device registries, a copy of the recorder database), without an API token, as
  the
  [Home Assistant operations guide](./websites-src/home-lab-docs/guides/operations/home-assistant.md)
  describes; after a change that alters MQTT discovery payloads (a Zigbee2MQTT
  major upgrade), entities discovered before it stay unavailable until Home
  Assistant re-subscribes, which a restart does.
- **The Prometheus backend runs on raspberrypi2** (port 9090, host-local). Query
  it over SSH for historical metrics evidence during incident investigations;
  the
  [unresponsive host runbook](./websites-src/home-lab-docs/guides/troubleshoot-unresponsive-host.md)
  has the query examples and the investigation workflow.
- **Prometheus Alertmanager runs on raspberrypi2** (port 9093, host-local),
  routing alerts to Telegram. Planned host downtime fires availability alerts by
  design: silence it via `amtool` instead of touching the alert rules, as
  documented in the
  [monitoring operations guide](./websites-src/home-lab-docs/guides/operations/monitoring.md),
  which also sizes the silence past the alert's own duration and covers the
  probe alerts with a second silence.
- **The Proxmox nodes take tag-scoped node playbook runs only:** a full
  `home-lab-node.yaml` run on pve1 or pve2 applies the SSH hardening that locks
  out the root login the lab uses, among other stacks the nodes should not run
  (the todo item "The Proxmox nodes have only ever had tag-scoped node runs"
  lists them); `--tags untagged` is the safe subset. The `proxmox-node.yaml`
  playbook does not converge pve2 either: its kernel task assumes the
  `proxmox-boot-tool` layout and pve2 boots through GRUB (same todo item).
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
- **Power measurements use the smart plug series in Prometheus**, not software
  estimates: the
  [host power guide](./websites-src/home-lab-docs/guides/operations/host-power.md)
  has the query recipe and the measured baselines per host.

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
- **Run the Molecule tests locally before pushing Ansible changes:** test the
  playbooks that the change affects (`main` covers all the roles) with
  `ANSIBLE_TEST_DISTRO=<image> ANSIBLE_TEST_PLAYBOOK_NAME=<playbook> scripts/run-ansible.sh "molecule test"`
  (both variables and the SSH agent socket are required), as described in the
  [operational scripts guide](./websites-src/home-lab-docs/guides/development/operational-scripts.md).
  The tests start privileged containers on the control machine, so get approval
  first, and state in the commit proposal whether the run happened or why it was
  skipped. Tag new tasks that pull container images or start containerized
  services with `molecule-notest`.
