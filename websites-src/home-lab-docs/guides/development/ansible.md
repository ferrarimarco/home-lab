# Ansible development

This document describes how the `ferrarimarco_home_lab_node` Ansible role is
structured, so that changes to it converge reliably. For how to run playbooks,
see the [operational scripts guide](./operational-scripts.md).

## Role architecture: data-driven stacks

The role configures hosts through per-workload "stacks" (monitoring,
media-stack, monitoring-apt, ...). Each stack contributes its resources
(directories, files, templates, services, Compose projects) as data, and a small
set of generic tasks applies that data:

1. Each stack defines its resources in a dedicated vars file
   (`roles/ferrarimarco_home_lab_node/vars/<stack>-stack.yaml`), with every
   resource's `state` derived from the stack's enablement flag via `ternary`
   (for example `{{ configure_monitoring_apt | ternary('file', 'absent') }}`).
2. `tasks/include-variables.yaml` aggregates the per-stack lists into global
   custom facts. Each stack appears as one entry with an `enable_custom_fact`
   switch and a `fact_category` name.
3. The `fact_category` name doubles as the stack's **tag**: running the playbook
   with `--tags '<fact_category>' --tags untagged` selects that stack plus the
   global untagged initialization tasks.
4. Generic, untagged tasks in `tasks/main.yaml` (configure directories, render
   templates, download files, manage services) then apply the aggregated data.

Because a disabled stack still contributes its resources with `state: absent`,
running a stack's tag with its enablement flag unset **tears the stack down**
rather than skipping it. This is intentional (declarative removal), but it means
an unexpected `absent` prediction in check mode must be treated as a signal that
an enablement flag resolved differently than intended.

## Enablement flags

- Stacks are enabled per host through `configure_<stack>` variables in
  `host_vars`, with role defaults of `false` in `defaults/main.yaml`.
- **Debian-conditional stacks** (such as `monitoring-apt`) are instead enabled
  for every Debian host in `tasks/register-Debian-facts.yaml` with the pattern:

    ```yaml
    - name: Set configure_monitoring_apt to allow for eventual overriding
      ansible.builtin.set_fact:
          configure_monitoring_apt:
              "{{ configure_monitoring_apt | default(true) }}"
    ```

    The `default(true)` fallback only fires when the variable is otherwise
    **undefined**, which is what lets `host_vars` overrides win. Do not add a
    role default for such a variable: a `defaults/main.yaml` entry makes the
    variable always defined, silently pins it, and disables the stack everywhere
    (this regression shipped between 2025-07 and 2026-09 for `monitoring-apt`).

## Python exporter services

systemd services that run Python-based exporters build their virtual environment
through the shared `/usr/local/bin/build-python-venv` script (source:
[`files/scripts/build-python-venv.sh`](https://github.com/ferrarimarco/home-lab/blob/master/config/ansible/roles/ferrarimarco_home_lab_node/files/scripts/build-python-venv.sh)),
never through inline `ExecStartPre` venv and pip commands:

- The script rebuilds the venv only when the requirements file's hash or the
  system Python version changes, or when the venv is broken; otherwise a start
  costs one hash check.
- The venv lives in the unit's `StateDirectory=` (`/var/lib/<unit>`), not in
  `/run`: systemd creates the state directory before assembling the mount
  namespace, so it composes with `ProtectSystem=strict`, and it survives
  reboots. Mount-namespace directives such as `ReadWritePaths=` are assembled
  before any `ExecStartPre` runs, so they must never reference a path a command
  in the unit is supposed to create.
- Reference implementation: the `monitoring-apt` unit template
  (`templates/monitoring-apt/monitoring-apt.service.jinja`).

## Authorized keys on Proxmox nodes

The bootstrap role declares the complete set of root authorized keys with
`exclusive: true`. On Proxmox nodes two things complicate that:

- `/root/.ssh/authorized_keys` is a symlink to the cluster-shared
  `/etc/pve/priv/authorized_keys`. The `ansible.posix.authorized_key` module
  writes a temporary file and renames it over the target, which replaces the
  symlink with a regular file and leaves the shared file untouched. At the next
  `pveproxy` start (every boot runs `pvecm updatecerts --silent`), Proxmox
  renames the regular file aside, recreates the symlink, and merges the file
  back into the shared one, so stale keys return and the repository key
  accumulates duplicates. The role therefore stats the user's file and, when it
  is a symlink, converges the link target (`path` set to the target,
  `manage_dir: false`).
- The same merge step always appends the node's own root key
  (`/root/.ssh/id_rsa.pub`), so an exclusive key set that omits it flaps on
  every boot. `setup-Proxmox.yaml` reads that key and registers it in
  `bootstrap_additional_authorized_keys`, which the key task appends to the
  repository key. The read is guarded by a `stat` because only the Proxmox
  installer generates the key: the Molecule instance runs the Proxmox tasks
  without it.

Two Jinja details matter in that key task: the additional keys default to an
empty list because a task skipped by tags registers nothing, and the scalar is
double-quoted so that YAML turns the `\n` separator into a real newline. In a
folded scalar the escape reaches Jinja literally, and the module then writes all
the keys on one line.

A future cluster needs the peer nodes' keys in the set as well (read them with
`delegate_to`, tolerating a powered-off node); there is no cluster today.

## Check mode conventions

- Always run `--check --diff` (capturing the full output to a log file) and
  review the predicted changes before applying. Watch specifically for
  unexpected `state: absent` predictions (see enablement flags above).
- `ansible.builtin.get_url` tasks always report `changed` in check mode: the
  module cannot verify remote content without downloading. Confirm against the
  real run before treating such a prediction as drift.
- Design tasks so check mode runs cleanly and truthfully on first runs:
  state-query tasks carry `changed_when: false` and `check_mode: false`, and
  later tasks tolerate resources that an earlier task would have created.
