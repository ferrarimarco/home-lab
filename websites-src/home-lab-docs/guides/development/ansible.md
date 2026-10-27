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
   APT repositories (`<stack>_os_package_repositories`) are deb822 sources
   applied by `ansible.builtin.deb822_repository` (`name`, `uris`, `suites`,
   `components`, `signed_by`, `state`); an entry lists under `legacy_file_paths`
   the files that earlier `apt_key` and `apt_repository` tasks created, and the
   role removes them before applying the source.
2. `tasks/include-variables.yaml` lists the stacks as data (`node_stacks`): each
   stack is one entry with an `enable_custom_fact` switch, a `fact_category`
   name, and its resource lists. One `set_fact` task filters the entries by the
   run's tags and by enablement, and appends their lists to the global custom
   facts; the entries of selected but disabled stacks also feed the teardown
   lists.
3. The `fact_category` name doubles as the stack's **tag**: running the playbook
   with `--tags '<fact_category>' --tags untagged` selects that stack plus the
   global untagged initialization tasks.
4. Generic, untagged tasks in `tasks/main.yaml` (configure directories, render
   templates, download files, manage services) then apply the aggregated data.

Conventions the stacks rely on:

- **Timer-driven units carry no `[Install]` section and no restart entry.** A
  oneshot service with `WantedBy=multi-user.target` can be enabled on its own
  and then runs at every boot (the Docker prune did on raspberrypi2 until
  2026-10-12); restarting the service runs the job, and so does restarting the
  timer on systemd 252 (observed on hl01 the same day, not on raspberrypi2's
  247). Leave `os_services_to_restart` out of both entries: the daemon reload
  that follows rendering re-reads the units and recomputes the timer's next
  elapse (expected from systemd's reload semantics; a schedule change has not
  exercised it yet). A unit without `[Install]` reports `static`, which the
  systemd module counts as enabled, so it is not declared in `os_services`
  either: declare the timer.
- **Workload state lives in bind-mounted directories** under the configuration
  and runtime trees, which restic backs up, never in named or anonymous volumes.
  Containers and images are disposable, so the weekly
  `docker system prune --all --force --volumes` can remove them without losing
  anything; the backups are the recovery path, and a volume that ever held state
  would be unbacked.
- **A changed file restarts, or reloads, the services that read it.** An entry
  in a stack's file or template list carries `os_services_to_restart`,
  `docker_compose_services_to_restart` (the whole Compose project, after the
  file changed), or `docker_compose_services_to_reload` (a `SIGHUP` to one
  service of the project, for a service that re-reads its files on the signal
  and keeps its runtime state, as Prometheus keeps its alert state). A reload
  only works when the container sees the new file: a single-file bind mount
  keeps the inode the container opened, so the Prometheus configuration and
  rules live in a directory mounted as a directory. Grafana's dashboard
  definitions carry no hook at all: its provisioner re-reads them on its
  interval.
- **Every Compose project has a oneshot unit, and the playbook starts it through
  that unit.** `tasks/setup-docker-compose-units.yaml` renders
  `docker-compose-up-<project>.service` for each item of
  `docker_compose_up_items` (the project name is the compose file's directory,
  Compose's default), wanted by `multi-user.target` so the host brings its
  projects up at boot without the control machine, and enables it when the
  item's `start_containerized_services` is true. The start task runs
  `systemctl start` on the unit and reads the Compose output from the journal of
  that invocation, so a deploy exercises the unit the next boot depends on; the
  restart, reload, stop, and removal tasks keep calling Compose directly, since
  they are not "bring the project up". An item whose containers bind a network
  share lists its mount points in `required_mount_paths`: the unit then carries
  `RequiresMountsFor=` and is wanted by the mount units too, so every start of
  the mount runs the project again (the
  [NAS LXC container page](../../architecture/nas-lxc-container.md), SMB clients
  section, has the design). The units of a stack a run disables are disabled and
  removed in that run, whatever its tag scope; units of projects that no longer
  exist in the role are swept by full runs only, since a tag-scoped run
  registers the selected stacks' items alone and would remove the rest.
- **Templates for files the workload rewrites are seeds.** A file the
  application edits at runtime (qBittorrent's settings, the Zigbee2MQTT secret,
  the Wi-Fi credentials) is rendered with `force: false`: it seeds a fresh host
  and is never touched again, so the settings beyond the seed are owned by the
  application's own interface, and a template change reaches only fresh hosts or
  a deliberate re-seed (the [backup operations guide](../operations/backup.md)
  has the qBittorrent recipe). Render the seed where the image reads it:
  qBittorrent's was rendered one level above its directory and went unread for
  twenty months.

Because a disabled stack still contributes its resources with `state: absent`,
running a stack's tag with its enablement flag unset **tears the stack down**
rather than skipping it: its containers are stopped and removed first, through
the `docker_compose_disabled_items` fact, then its files, then its project unit.
This is intentional (declarative removal), but it means an unexpected `absent`
prediction in check mode must be treated as a signal that an enablement flag
resolved differently than intended.

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

## The backup role

`ferrarimarco_home_lab_backup` runs restic jobs on hosts without a container
engine (the Proxmox nodes), from the packaged restic binary and the same job
script the node role's Compose job uses: the role owns `files/entrypoint.sh`,
and the node role's copy is a symlink to it, so the two flavours never drift. It
has its own playbook, `backup.yaml`, chained into `main.yaml` after the node
playbook and gated by data, so it is safe on every host with no limit and no
tags: a host opts in with `configure_backup_restic_native` and a
`restic_native_backup_jobs` list (the role defaults document the fields), and
every other host converges the role's resources to absent.

Per job the role renders a root-only environment file (repository, password,
backup set, drill settings, single-quoted, which systemd reads literally: the
role asserts the password holds no quote or newline), the backup and drill
services and timers, and initializes a missing repository through `systemd-run`
with that environment file, after the same root-filesystem check as the Compose
job. The repositories are created, never removed: an opt-out stops the timers
and removes the units and files, and keeps the snapshots. The units write only
the repository, the drill target, the metrics, and the restic cache
(`ProtectSystem=strict`, with `CacheDirectory=` for the cache), and order after
`zfs-mount.service`, since a ZFS dataset has no mount unit for
`RequiresMountsFor=` to require. The metrics go to the textfile directory of the
Debian `prometheus-node-exporter` package by default
(`restic_native_textfile_collector_directory`), which the nodes run; a host on
the node role's containerized exporter overrides it.

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

The exclusive set applies to every host, not only Proxmox nodes: keys added by
hand on a host (hardware security keys, for example) disappear at the next
bootstrap run unless the repository declares them. The user and key tasks carry
the `authorized-keys` tag, so a host whose OS tasks cannot run yet (raspberrypi2
on Debian 11, whose release has no `non-free-firmware` component) still gets its
keys converged with `--tags authorized-keys`; on a Proxmox node pair it with
`proxmox`, which registers the node's own key.

## Check mode conventions

- Always run `--check --diff` (capturing the full output to a log file) and
  review the predicted changes before applying. Watch specifically for
  unexpected `state: absent` predictions (see enablement flags above).
- Every download entry declares a `checksum` (`sha256:<hash>`) next to its URL
  pin. With it, `ansible.builtin.get_url` reports an unchanged destination
  without a request, in check mode too; without it, check mode always predicts a
  change, since its HEAD request carries no content to compare. A pin moved
  without a new hash fails the download instead of deploying unverified content.
- Design tasks so check mode runs cleanly and truthfully on first runs:
  state-query tasks carry `changed_when: false` and `check_mode: false`, and
  later tasks tolerate resources that an earlier task would have created.

## Secrets and vault files

Secret values reach the role only through `vault_*` variables defined in the
gitignored Ansible vault files, host or group scoped, as the secrets policy in
the repository's
[AGENTS.md](https://github.com/ferrarimarco/home-lab/blob/master/AGENTS.md) sets
out: nothing secret is committed, encrypted or not. A new secret therefore means
a new `vault_*` variable that the user adds with the vault edit mode of
`run-ansible.sh`, which the
[operational scripts guide](./operational-scripts.md) documents together with
the read-only view mode and the key-name listing that checks a variable exists
without printing its value. Both modes run without an SSH agent.

## Coral driver delivery

Google retired the Coral APT repository (`packages.cloud.google.com/apt` answers
403 Forbidden) and archived the gasket driver source at version 1.0-18, and
Debian packages neither the driver nor the EdgeTPU runtime. The
`ferrarimarco_home_lab_coral` role therefore installs the `gasket-dkms` package
from a pinned release asset of the
[gasket-builder](https://github.com/jnicolson/gasket-builder) project, the path
Frigate's documentation points to: it builds the archived source plus
kernel-compatibility patches. The pin (release tag and sha256) lives in the
role's `vars/main.yaml`; to bump it, download the new asset, verify it, and
update both values. The host needs only the kernel driver: Frigate's container
ships its own EdgeTPU runtime and the Coral exporter reads the device
temperature from sysfs, so the role removes the `libedgetpu1-std` runtime
package that the old repository installed.
