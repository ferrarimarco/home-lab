# AI Agent Instructions & Guidelines

This document holds the rules that AI coding agents follow in the `home-lab`
repository, each with a pointer to the guide or specification that holds the
knowledge behind it. A rule here is a sentence and a link: the substance of a
task (commands, invocation patterns, recipes, decisions) goes in the guides and
the specifications, as the
[documentation guide](./websites-src/home-lab-docs/guides/development/documentation.md)
describes, never in this file.

## Specifications and Documentation

- **Read the relevant specification before changing Nix, Terraform, Ansible, or
  CI code**, for its constraints, design splits, security rules, and naming
  conventions, and update its status table and the specs index as soon as the
  change is tested, with the status semantics the documentation guide defines.
- **Todo items live only in the specs index**, as the
  [todo list guide](./websites-src/home-lab-docs/guides/development/todo-list.md)
  describes: a specification carries no future work of its own, work paused
  between sessions is a todo item, and the progress of a rollout goes in the
  status tables.
- **Guides are the knowledge base:** record reusable knowledge in the guide for
  its topic, creating one if needed; link to where a fact already lives instead
  of restating it, and keep a procedure in one place. The agent memory store
  holds only what the repository cannot: workstation facts and private
  identifiers, each behind a one-line index entry.
- **Markdown:** file references are relative Markdown links, and committed
  documentation carries no private identifiers; the global instructions carry
  the other style rules.
- **Rebuild the docs site after editing `websites-src/`** with
  `scripts/run-mkdocs.sh` and commit the regenerated `docs/` output with its
  sources, following the format, build, lint, commit pipeline of the
  [site development guide](./websites-src/home-lab-docs/guides/development/website-development.md);
  the build reads the working tree, other sessions' files included, and the
  guide has the worktree recipe for that case.

## Operational Scripts

Use the repository's scripts instead of ad-hoc commands; the
[operational scripts guide](./websites-src/home-lab-docs/guides/development/operational-scripts.md)
describes each one with its environment variables and invocation patterns, and
CLI tooling comes from the Nix dev shells of the
[Nix development shells guide](./websites-src/home-lab-docs/guides/development/nix-dev-shells.md),
never from the host.

- **Terraform only via `scripts/run-terraform.sh`:** ask before any run that
  contacts the Proxmox API (nodes may be powered off), run with stdin closed so
  the first pending plan prints and aborts as the review pass, and check for
  changes Proxmox holds for the next start after every VM change.
- **Ansible only via `scripts/run-ansible.sh`:** pick the narrowest playbook
  under `config/ansible/playbooks/`, run `--check --diff` first with the full
  output captured to a log outside the repository (it embeds rendered secrets),
  review the predictions for unexpected `state: absent` teardowns, and run from
  a temporary worktree when other sessions have changes under `config/ansible`.
- **Run the Molecule tests before pushing Ansible changes:** the playbooks the
  change affects, scoped by tag while iterating and unscoped once before the
  push; the tests start privileged containers, so get approval first and state
  in the commit proposal whether the run happened.
- **Every Prometheus alerting rule gets a firing and a non-firing promtool
  case** under `test/prometheus-rules/`, run with
  `test/scripts/prometheus-rules-test.sh` before committing, and the status
  table of the
  [monitoring-alerting spec](./websites-src/home-lab-docs/architecture/monitoring-alerting.md)
  follows the rule count in the same change.
- **Run the affected host's NixOS flake check before pushing**, as the
  [Nix development guide](./websites-src/home-lab-docs/guides/development/nix.md)
  describes.
- **Lint with `scripts/lint.sh` before committing** (`scripts/format.sh` while
  editing) and read the results from its output files; Prettier owns Markdown
  formatting, so never hand-align a table, and re-read a file after a run. The
  guide has the details on fix mode, staging after a run, new and deleted files,
  and YAML comments.
- **Validate commit messages with the lint script's commit message mode** before
  proposing a commit; CI validates every pushed commit.
- **Read the
  [dependency updates guide](./websites-src/home-lab-docs/guides/operations/dependency-updates.md)**
  before changing `.github/dependabot.yaml` or investigating a missing pull
  request.

## Design Rules

- **Decouple architecture from deployment:** framework specifications (how
  testing or bootstrapping works in general) stay separate from host
  specifications, which hold only the physical and logical declarations of one
  machine.
- **Only guests that serve other guests declare a Proxmox startup order;**
  consumers of their shares stay unordered, as the
  [LXC](./websites-src/home-lab-docs/architecture/proxmox-lxc.md) and
  [VM](./websites-src/home-lab-docs/architecture/proxmox-vm.md) framework specs
  explain.

## Secrets

- **Nothing secret is ever committed, even encrypted:** vault files and
  `*-secrets.tfvars*` files are gitignored by design, and committing ciphertext
  was rejected because public Git history is immortal.
- **Secrets reach configuration through `vault_*` variables** of the untracked
  Ansible vault and tfvars files. Agents cannot edit vault files: give the user
  the variable name and the vault edit mode of `scripts/run-ansible.sh`, and
  verify that a variable exists by listing key names through its view mode, as
  the operational scripts guide describes.
- **Check-mode logs embed rendered secrets:** keep them in the session
  scratchpad and mask the values when quoting.

## Operating on Deployed Hosts

- **Reach the hosts over SSH as the
  [Linux administration notes](./websites-src/home-lab-docs/guides/useful-linux-admin-commands.md)
  describe;** use read-only commands freely, get approval for state-changing
  ones, load the `apply-infra-change` skill before an apply, an upgrade, or a
  reboot, and verify afterwards with read-only checks whose evidence the report
  carries.
- **Workloads on Debian hosts are Compose projects** under
  `/etc/ferrarimarco-home-lab/<service>/compose.yaml`, managed through
  `docker compose -f <that file>` and never through raw `docker stop/start`;
  every project has a systemd unit that brings it back, as the
  [network share clients guide](./websites-src/home-lab-docs/guides/operations/network-shares.md)
  describes together with the empty-library check.
- **Repository image pins are not what runs until Ansible re-rendered the
  stack:** read the host's rendered compose file or `docker ps` before stating a
  deployed version.
- **Migrations follow the
  [container migration guide](./websites-src/home-lab-docs/guides/operations/container-migration.md);**
  never improvise one.
- **Where a service runs and how to read it is in the operations guides:** the
  [Home Assistant](./websites-src/home-lab-docs/guides/operations/home-assistant.md),
  [monitoring](./websites-src/home-lab-docs/guides/operations/monitoring.md)
  (the backends on raspberrypi2, the silences for planned downtime),
  [network boot](./websites-src/home-lab-docs/guides/operations/network-boot.md)
  (the rescue toggle on hl02 decides what a host boots), and
  [host power](./websites-src/home-lab-docs/guides/operations/host-power.md)
  (smart plug measurements, the pve2 policy of running 24/7 with no HDD
  spin-down) guides, the
  [Proxmox administration notes](./websites-src/home-lab-docs/guides/proxmox-admin-notes.md)
  (`pct exec` into a NixOS container needs the full binary path), and the
  [Ansible development guide](./websites-src/home-lab-docs/guides/development/ansible.md)
  (the node role's settings for the Proxmox nodes; pve2's first full run waits
  on the host, as the specs index records).

## Ansible Conventions

- **Use the `ansible-developer` skill for any Ansible change;** warn the user
  when it is not available.
- **Read the Ansible development guide before changing a role:** it describes
  the node role's stack, tagging, and enablement machinery, the rules on
  enablement flags and Python exporter services, and the Proxmox nodes'
  settings.
