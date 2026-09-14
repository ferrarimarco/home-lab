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
