# AI Agent Instructions & Guidelines

This document outlines the rules that AI coding agents must follow when working
in the `home-lab` repository. It carries rules and pointers: the knowledge
itself lives in the guides and specifications it links to.

## Living Specifications & Documentation Integrity

This repository relies on **living design specifications** to guide all
architectural, testing, and deployment choices before code is modified. These
specs are located in `websites-src/home-lab-docs/architecture/`, the
architecture section of the docs site.

### Specifications Index & Status Tracking

The architecture section entrypoint
[`websites-src/home-lab-docs/architecture/README.md`](./websites-src/home-lab-docs/architecture/README.md)
acts as a global index. It features an index table outlining the architectural
scope and overall **Current Implementation Status** of each specification.
Whenever a specification's status table changes, update this column for that
specification to reflect the latest state.

### Individual Spec Status Tables

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

As soon as code changes are successfully tested and completed (or when a logical
sub-task is finished), update the `Status` and `Details` fields of the modified
components with precise, objective details (e.g., "MAC declared in Terraform;
awaiting test verification"), then update the global index. This prevents
configuration drift between the specifications and the code.

### Centralized Future Work and TODOs

Future work and todo items are tracked centrally in the "Specifications to write
and TODOs" section of the specs index
[`README.md`](./websites-src/home-lab-docs/architecture/README.md), so they are
never scattered across specifications: a spec carries no "Future Work" section
and no todo items of its own. The list is organized in themed subsections with a
"Current focus" priority list and `Depends on:`/`Blocks:` dependency
annotations: follow the
[Todo list management guide](./websites-src/home-lab-docs/guides/development/todo-list.md)
when adding, completing, or discarding items.

### Documentation Placement

[`websites-src/home-lab-docs/architecture/`](./websites-src/home-lab-docs/architecture/)
holds the design and the as-built description of each subsystem: a page with a
status table is a specification, and its status table, not a separate section,
tells design from reality. Reference pages (software candidates, references) sit
beside the specifications with no status table and no row in the specifications
index table, and the index lists them. Forward-looking material, intentions
included, goes in the todo list of the index, not in a page that reads as a
description of the lab; procedures go in the guides.

### Guides Are the Knowledge Base

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

## Agent Workflow

Before writing any Nix, Terraform, or CI workflow code, read the relevant design
specifications to understand constraints, design splits, security rules (like
SSH key guards), and naming conventions. Implement the change as approved, and
synchronize the specification status tables as soon as it is tested, as
described above.

## Markdown & Documentation Style Rules

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

## Operational Scripts

Use the repository's operational scripts for common development and maintenance
tasks instead of ad-hoc commands. The
[operational scripts guide](./websites-src/home-lab-docs/guides/development/operational-scripts.md)
describes them all, with their environment variables and invocation patterns.
Key rules:

- **Tooling via Nix dev shells:** CLI tooling is not installed on the host; it
  comes from the dev shells defined in `config/nix` (`default` and
  `operations`). Invoke tools as
  `nix develop ./config/nix#operations --command <cmd>` from the repository
  root. The
  [Nix development shells guide](./websites-src/home-lab-docs/guides/development/nix-dev-shells.md)
  lists the tools in each shell and how to invoke them, including when to use
  the GitHub CLI (`gh`) and which of its subcommands need approval. When
  changing the packages of a shell, update the guide in the same change.
- **Terraform only via `scripts/run-terraform.sh`,** from the operations dev
  shell. Ask the user before any run that contacts the Proxmox API (nodes may be
  powered off), and run it with stdin closed (`</dev/null`) so the first stack
  with pending changes prints its plan and aborts at the approval prompt: use
  that as the review pass, and supply the approval on a second run only after
  reviewing the plan, as the operational scripts guide describes. After every VM
  change, check for changes Proxmox holds for the next start, as the same guide
  describes.
- **Ansible via `scripts/run-ansible.sh`:** runs containerized, needs the SSH
  agent socket, and takes the playbook, extra flags, and vault modes through
  environment variables, as the operational scripts guide describes together
  with the tag-scoped invocation pattern. Select the narrowest playbook under
  `config/ansible/playbooks/` that covers the change (`main.yaml` chains most of
  the other playbooks, several of whose plays target all hosts). Always run
  `--check --diff` first, capture the full output to a log file, and review the
  predictions for unexpected `state: absent` teardowns before applying. A run
  reads the working tree like the docs build: before an apply, check the status
  for other sessions' changes under `config/ansible` and, when there are any,
  run from a temporary worktree at the reviewed commit, as the guide describes.
- **Prometheus alerting rules need a promtool unit test:** every rule in
  `prometheus-alerting-rules.yaml` gets a firing and a non-firing case in
  `test/prometheus-rules/`; run `test/scripts/prometheus-rules-test.sh` before
  committing. The operational scripts guide has the test conventions. The status
  table of the
  [monitoring-alerting spec](./websites-src/home-lab-docs/architecture/monitoring-alerting.md)
  names the probe kinds and the rule count the test script prints: update it in
  the same change as the rule.
- **NixOS integration tests:** every host directory is auto-registered as a
  flake check; run the affected host's check locally before pushing, as the
  [Nix development guide](./websites-src/home-lab-docs/guides/development/nix.md)
  describes together with the test-script authoring gotchas.
- **Docs site via `scripts/run-mkdocs.sh`:** rebuild after spec changes and
  commit the regenerated `docs/` output, following the format-build-lint-commit
  pipeline of the
  [site development guide](./websites-src/home-lab-docs/guides/development/website-development.md).
  The build reads the working tree, including the uncommitted and untracked
  files of other sessions: before committing generated output, confirm that its
  differences only reflect the sources in the same commit, as the guide
  describes.
- **Linting:** lint and format changes with `scripts/lint.sh`, which runs
  super-linter with the same configuration as CI; the operational scripts guide
  documents its modes, its output files, and `scripts/format.sh` for targeted
  formatting while editing. Do not hand-roll style checks or hand-align Markdown
  tables: Prettier's fix mode owns formatting, including table alignment, and
  rewraps prose and re-pads tables, so the global re-read-after-formatting rule
  applies to every run. Read the results from the output files the guide
  describes, and follow its rules on fix mode, console output, and concurrent
  runs. A lint run can unstage staged changes, so stage files after linting,
  right before committing; a new file is linted only once committed, so commit,
  lint, and amend.
- **Validate commit messages before proposing commits** with the lint script's
  commit message mode, as the operational scripts guide describes. A lint run
  only validates the message of the last commit, while CI validates all the
  pushed commits.
- **Dependency updates:** Dependabot opens the dependency update pull requests,
  configured in `.github/dependabot.yaml`. Read the
  [dependency updates guide](./websites-src/home-lab-docs/guides/operations/dependency-updates.md)
  before changing that file or investigating missing or stuck pull requests.

## Design & Modularization Rules

When introducing new hosts, roles, or automation features, adhere to these
architectural patterns:

- **Decouple Architecture vs. Deployment:** Never combine global infrastructure
  logic (e.g., how integration testing or bootstrapping works in general) with
  host-specific configuration details. Design modular, reusable specs for the
  framework (under `websites-src/home-lab-docs/architecture/`) and keep
  individual host specs focused exclusively on physical/logical declarations for
  that machine (e.g., specific VM core count, dedicated RAM, and MAC address).

- **Only guests that serve other guests declare a Proxmox startup order;**
  consumers of their shares stay unordered. The reference patterns in the
  [LXC](./websites-src/home-lab-docs/architecture/proxmox-lxc.md) and
  [VM](./websites-src/home-lab-docs/architecture/proxmox-vm.md) framework specs
  carry the convention and the reasoning.

## Secrets Policy

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
  material by listing key names only, through the vault view mode of
  `scripts/run-ansible.sh` that the
  [operational scripts guide](./websites-src/home-lab-docs/guides/development/operational-scripts.md)
  documents (neither the host nor the Nix dev shells provide `ansible-vault`).
- `--check --diff` output embeds rendered secret-bearing files (vault values
  included). Redirect such logs to the session scratchpad, not the repository,
  and mask secret values when quoting from them.

## Operating on Deployed Hosts

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
  inventory flag choreography around a verified data copy, including the
  cross-host endpoint variables to repoint. Check target capacity and stop the
  stack before copying its state; do not improvise migrations with ad-hoc
  commands or scripts.
- **A container that lists an empty library may hold the bare mount point, not
  the share**, and **every Compose project has a systemd unit that brings it
  back** at boot, at mount start, and after a manual stop: the
  [network share clients guide](./websites-src/home-lab-docs/guides/operations/network-shares.md)
  has the checks, the recovery steps, and how to park a project.
- **Reach the hosts over SSH as the
  [Linux administration notes](./websites-src/home-lab-docs/guides/useful-linux-admin-commands.md)
  describe** (fully qualified names, one login user per host). Use read-only
  commands freely for discovery; get approval for state-changing commands.
- **Home Assistant state is read from its storage files on hl01**, without an
  API token, as the
  [Home Assistant operations guide](./websites-src/home-lab-docs/guides/operations/home-assistant.md)
  describes.
- **The Prometheus backend and Alertmanager run on raspberrypi2**, host-local.
  Query Prometheus over SSH for historical metrics evidence during incident
  investigations, following the
  [unresponsive host runbook](./websites-src/home-lab-docs/guides/troubleshoot-unresponsive-host.md).
  Planned host downtime fires availability alerts by design: silence them via
  `amtool` instead of touching the alert rules, as the
  [monitoring operations guide](./websites-src/home-lab-docs/guides/operations/monitoring.md)
  describes, which also explains why a down target is not necessarily an outage.
- **Interim guard: run the node playbooks on pve1 and pve2 only with tags**
  (`--tags untagged` is the safe subset) until the todo item "The Proxmox nodes
  have only ever had tag-scoped node runs" in the
  [specs index](./websites-src/home-lab-docs/architecture/README.md) is
  resolved: a full run applies stacks the nodes should not run, including an SSH
  hardening that locks out the login the lab uses. The item lists the stacks and
  the pve2 kernel task gap of `proxmox-node.yaml`; remove this guard with it.
- **`pct exec` into a NixOS container needs the full binary path or a login
  shell wrapper**, as the
  [Proxmox administration notes](./websites-src/home-lab-docs/guides/proxmox-admin-notes.md)
  describe; the bare command fails with "No such file or directory".
- **pve2 runs 24/7 by user policy, with no HDD spin-down:** never propose or
  configure HDD standby on pve2. The pve2 section of the
  [host power guide](./websites-src/home-lab-docs/guides/operations/host-power.md)
  records the reason and the levers that remain allowed.
- **Verify state-changing operations** (Terraform applies, playbook runs,
  bootstrap handoffs) afterward with read-only checks over SSH (`findmnt`,
  `zfs list`, `pct config`, `systemctl is-active`, ...) and report the evidence.
- **Power measurements use the smart plug series in Prometheus**, not software
  estimates: the
  [host power guide](./websites-src/home-lab-docs/guides/operations/host-power.md)
  has the query recipe and the measured baselines per host.

## Ansible Conventions

- **Use the `ansible-developer` skill for any Ansible change:** it carries the
  generic conventions this repository follows (read-then-act for non-idempotent
  modules, assert-don't-automate destructive host state, data-driven roles,
  check-mode friendliness). If the skill is not available, warn the user.
- How the `ferrarimarco_home_lab_node` role's stack, tagging, and enablement
  machinery works is documented in the
  [Ansible development guide](./websites-src/home-lab-docs/guides/development/ansible.md);
  read it before changing the role. Two of its rules bear repeating: never add
  role defaults for Debian-conditional enablement flags (a `defaults/main.yaml`
  entry silently pins them and disables the stack), and Python exporter services
  build their venv through the shared `build-python-venv` script into a systemd
  `StateDirectory=`, never through inline `ExecStartPre` commands.
- **Run the Molecule tests locally before pushing Ansible changes:** test the
  playbooks that the change affects (`main` covers all the roles), as the
  [operational scripts guide](./websites-src/home-lab-docs/guides/development/operational-scripts.md)
  describes. While iterating on one stack, scope the run by tag as the guide
  describes, and run the full unscoped test once before pushing. The tests start
  privileged containers on the control machine, so get approval first, and state
  in the commit proposal whether the run happened or why it was skipped. Tag new
  tasks that pull container images or start containerized services with
  `molecule-notest`.
