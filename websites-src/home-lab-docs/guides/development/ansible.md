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
  section, has the design). An item whose containers are passed devices lists
  them in `required_device_paths`: the unit requires and runs after the device
  units systemd derives from the paths, `/dev` symlinks included, and is wanted
  by them, so a device that appears after boot runs the project again, where
  Compose would otherwise fail at once on the missing path. The units of a stack
  a run disables are disabled and removed in that run, whatever its tag scope;
  units of projects that no longer exist in the role are swept by full runs
  only, since a tag-scoped run registers the selected stacks' items alone and
  would remove the rest.
- **Templates for files the workload rewrites are seeds.** A file the
  application edits at runtime (qBittorrent's settings, the Zigbee2MQTT secret)
  is rendered with `force: false`: it seeds a fresh host and is never touched
  again, so the settings beyond the seed are owned by the application's own
  interface, and a template change reaches only fresh hosts or a deliberate
  re-seed (the [backup operations guide](../operations/backup.md) has the
  qBittorrent recipe). Render the seed where the image reads it: qBittorrent's
  was rendered one level above its directory and went unread for twenty months.

- **A disabled stack removes only the packages that declare it.** A package
  entry with `state: absent` reaches the uninstall list only when it carries
  `uninstall_when_disabled: true`; a package the stack needs but does not own
  (`rsync`, which Proxmox depends on; `smartmontools`, which Proxmox and
  Debian's SMART collector need; `openssh-server`, which the run logs in
  through) carries a comment instead and stays installed when the stack is off.
  Before removing anything, the role simulates the removal of the listed
  packages that are installed (`apt-get --simulate --purge remove`) and fails
  the host when apt would take a package the list does not name: a dependency a
  release added since the flag was set (pve-manager depends on `rsync`; a check
  run on pve1 on 2026-11-10 predicted the removal of Proxmox with it) is found
  at runtime, not at design time. A package apt's sources no longer carry (a
  repository the disabled stack removed) is left out of the simulation, since
  the removal task treats it as already absent. Before the guard, the removal of
  `rsync` purged `raspi-firmware` from raspberrypi2 on the day of its re-image
  (2026-11-08): that package's kernel hooks copy a new kernel and its initramfs
  to the boot partition, so the host kept booting the kernel of its image,
  through a reboot that cleared the reboot-required flag, until the role
  declared the package for Raspberry Pi OS (2026-11-26). After a kernel upgrade
  on a Raspberry Pi, compare `uname -r` with the newest `/boot/vmlinuz-*` once
  it has rebooted.
- **A missing unit is converged when its state is `stopped`, or in check mode.**
  The service task lists every selected stack's units, enabled or not, so a
  disabled stack's unit may never have existed on the host, and in check mode
  the package that ships a unit was only predicted. A unit a real run wants
  `started` and cannot find fails the run: a misspelled name, or a stack enabled
  on a host whose package did not install.

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

`ferrarimarco_home_lab_backup` runs every restic job of the lab, on the Debian
workload hosts and on the Proxmox nodes alike, from the Debian restic package
and one job script, which the role owns (`files/entrypoint.sh`). It has its own
playbook, `backup.yaml`, chained into `main.yaml` after the node playbook and
gated by data, so it is safe on every host with no limit and no tags: a host
opts in by declaring a `restic_backup_jobs` list (the role defaults document the
fields), a job entry opts out with `state: absent`, and a host with no job
converges the role's resources to absent. The repositories are created, never
removed: an opt-out stops the timers and the exporter and removes the units and
files, and keeps the snapshots.

restic comes from each host's Debian package, converged present with jobs and
absent without. No minimum version is recorded anywhere: the job script has a
preflight mode that runs the cheapest command using the flags it relies on, and
the role runs it after the repository exists, so a host whose release ships a
package too old for the script fails the run with restic's own message, as the
job units do at runtime. Such a host is upgraded to a release that ships a
recent package rather than given one from elsewhere: a package pinned from
another release, or a binary installed by the role, was considered and rejected
as state that drifts from the host's release. The exporter's Python requirement
is repeated nowhere either: the role builds the venv at apply time with the
shared script, so a host whose Python the release refuses fails the run with
pip's own message, and the unit rebuilds the venv at start when the requirements
change. The exporter is pinned twice, by the tag of the `restic-exporter` stage
of the dependency updates helper Dockerfile, which Dependabot bumps, and by the
hash of its tarball in the role's variables, updated by hand as the
[dependency updates guide](../operations/dependency-updates.md) describes. Per
job the role renders a root-only environment file (repository, password, backup
set, drill settings, single-quoted, which systemd reads literally: the role
asserts the password holds no quote or newline), the backup and drill services
and timers, and an exporter service, and initializes a missing repository
through `systemd-run` with that environment file after a root-filesystem check.
The exporter is ngosang's restic exporter, installed from its release tarball
into a venv by the shared `build-python-venv` script (the requirements file is
rendered from the tag, and the venv built at apply time as well, so a host whose
Python the release refuses fails the run with pip's message), one service per
job on the job's port, started once the repository exists and, where the job
names the share's mount point, wanted by its mount unit so that it comes back
with the share. A host that cannot run the exporter yet declares
`restic_exporter_enabled: false` on the job, which drops the exporter and its
scrape target.

The units write only the repository, the drill target, the metrics, and the
restic cache (`ProtectSystem=strict`, with `CacheDirectory=` for the cache),
require the mounts systemd knows under the repository, and order after
`zfs-mount.service`, since a ZFS dataset has no mount unit for
`RequiresMountsFor=` to require. The metrics go to the textfile directory of the
Debian `prometheus-node-exporter` package by default
(`restic_textfile_collector_directory`), which the nodes run; the Debian
workload hosts declare the containerized exporter's directory in their group
variables, together with the workloads job. The monitoring backends derive the
`restic` scrape targets and the backup expectations from the same job
declarations, so a new job entry on any host is monitored with no other edit.

## The gateway role

`ferrarimarco_home_lab_gateway` converges the DHCP settings of the gateway, an
Asus router on the stock Asuswrt firmware, which keeps no dnsmasq configuration
file to own: it renders `/etc/dnsmasq.conf` from NVRAM variables at every start
of the service, and the web UI is a frontend to those variables. The role
therefore converges the variables: the pool bounds, the lease time, the DNS
servers handed to the clients (option 6), the LAN domain, and the reservation
list (`dhcp_staticlist`, one `<MAC>address>DNS>hostname` entry per device,
rendered only while `dhcp_static_x` is 1). Directives with no NVRAM variable (a
CNAME, a per-zone forward, `dhcp-boot`) are out of reach and belong to the lab
resolver.

The playbook, `gateway-dnsmasq.yaml`, is not chained into `main.yaml` and the
router is not in the static inventory: it runs BusyBox without Python, so the
fact gathering of every other play would fail on it. The first play registers it
as an in-memory host from the inventory's gateway definition and the vaulted
administration user and port (`group_vars/all/network.yaml` and the aliases in
`group_vars/all/main.yaml`), and the second play runs the role on it with the
`raw` module.

The Molecule test runs the playbook against a stand-in: the registered host's
connection and address are the router's unless the inventory sets
`gateway_ansible_connection` and `gateway_ansible_host`, which only the test
inventory does, pointing them at the test instance. The scenario's
`prepare-gateway-dnsmasq.yml` gives that instance the administration user and
two scripts in place of the firmware's `nvram` and `service` commands (one file
per variable; any `service` call other than the dnsmasq restart fails). The
three passes show that the role reads back what it wrote and that a second run
changes nothing, which a wrong rendering would pass too, so the scenario's
`verify-gateway-dnsmasq.yml` compares what the stand-in holds with literal
values written by hand from the test inventory (the reservations sorted by
address, every MAC in uppercase). The test does not cover the router's shell or
the size limit of a real NVRAM variable, for which the check run against the
router stays the test.

The router's shell is BusyBox (1.24.1 on the current firmware;
`busybox | head -1` prints the version): `/bin/sh` is the shell while the `sh`
first in `PATH` is a vendor memory-debugging tool, `setsid` is absent, and
`kill` takes a negative process group ID but rejects the `--` separator (`kill`
with no arguments prints the usage). The scripts the node role runs there over
one SSH session (see the `asuswrt-chkwan` service template) share that session's
process group with every child, as any non-interactive shell without job control
does.

The role follows the read-then-act pattern: it reads every managed variable in
one short `nvram get` loop (long batched commands have crashed the router's
shell), compares each with its desired value, prints the differences, and writes
only the differing variables, in one command that also commits them to flash and
restarts dnsmasq. In check mode the read still runs, the report task reports the
predicted changes as `changed`, and the write is skipped (`raw` does not support
check mode). A converged router reports no change.

The desired values come from the inventory: `gateway_dhcp` carries the service
settings, and the reservations are the union of every `network_interfaces` entry
of every inventory host that declares both `mac_address` and `ipv4_address`
(named after the host's short name, or the entry's `dhcp_hostname` for a device
such as a BMC) and the `gateway_dhcp_reservations` list for devices the
inventory does not declare as hosts (the cameras). The role replaces the whole
list: a reservation that exists on the router and not in the inventory is
removed by the next apply, so read the predicted `dhcp_staticlist` in the check
run before applying. Two guards fail the run before any write: a duplicated
address or MAC, and a rendered list longer than
`gateway_dhcp_staticlist_max_length`, since the variable's size limit is unknown
and a truncated write would silently drop reservations. The comparison is on the
whole rendered string, sorted by address, so a reservation added or reordered
through the router's web UI is reported as a difference and rewritten in the
inventory's order by the next run.

A new reservation for a host that holds a dynamic lease splits the name from the
address until the host renews: the router writes the reserved address to its
hosts file as soon as dnsmasq restarts, so the host's name resolves to an
address nothing holds yet, while the host keeps its lease until its renewal time
(half the lease, up to twelve hours here), when dnsmasq refuses the old address
and the host moves. Consumers that reconnect to the host by name in that window
fail (hl02's MQTT clients, 2026-10-28). Right after such an apply, renew the
lease on the host (`dhcpcd -n <interface>` on a host running dhcpcd), which
moves it within seconds at the cost of its open connections.

## The boot role

`ferrarimarco_home_lab_boot_bare_metal` powers a host on through its BMC when
the host declares one, sends a Wake-on-LAN magic packet to every MAC address the
host declares in `network_interfaces`, then waits up to ten minutes for the host
to answer over SSH. Its playbook, `boot-bare-metal.yaml`, is not chained into
`main.yaml`: powering a host on is an act of its own, and the
`community.general.wakeonlan` module sends nothing in check mode, so a full run
would wake and configure a host that its check run found powered off and made no
prediction for.

A host declares its BMC with `boot_bare_metal_bmc`, a mapping in its host
variables with the `address` of the BMC and the `user` and `password` of an
account that may control the chassis power, both from the host's vault file (the
[hardware operations guide](../operations/hardware.md#the-operator-account)
describes the account). The task runs `community.general.ipmi_power` on the
control machine, since IPMI over the LAN (UDP port 623) is routed traffic, and
the module needs the `pyghmi` library, which the Ansible container image
installs. The module reads the power state and changes it only when the host is
off, so it predicts in check mode too: `changed` for a host that is off, `ok`
for one that is on. Unlike a magic packet, the BMC confirms the power state, so
the task has no best-effort handling: a BMC that does not answer, a credential
it refuses, or a host that does not reach the on state fails the host at that
task, before the packets and the wait. The role only powers hosts on: powering
off or resetting a host that hangs stays a manual act, with the `ipmitool` of
the [operations shell](./nix-dev-shells.md#ipmi).

The Wake-on-LAN module sends one limited broadcast (`255.255.255.255`) from the
host that runs it, and no router forwards a limited broadcast, so the sender
must sit on the LAN segment of the host to wake. The role delegates the task to
`boot_bare_metal_wake_on_lan_relay_host`. The role default is the control
machine, which suits one on that segment; the inventory
(`group_vars/all/network.yaml`) names a lab host that is always on instead,
because the control machine reaches the LAN through routers and runs Ansible in
a container on Docker's bridge.

The send is best effort (`ignore_unreachable`): ansible-core removes a host from
the play when the host its task is delegated to cannot be reached (read in the
strategy plugin at ansible-core 2.21), so a relay that is down would otherwise
fail a host that is up. The wait is the verdict: with the relay down, a host
that is up passes it and one that is off fails it. The module reports nothing
about the packet's effect, so when a host stays off after a send, check that
Wake-on-LAN is armed on its interface (`Wake-on: g` in the `ethtool` output), or
power it on through its BMC with the `ipmitool` of the
[operations shell](./nix-dev-shells.md#ipmi).

Both paths were run against pve2 while it was off, watching its smart plug. On
2026-11-16, with the send delegated to the control machine, the host did not
wake in the ten-minute wait, while a packet sent by hand from raspberrypi2 woke
it within a minute. On 2026-11-17, with raspberrypi2 as the relay, the plug rose
from 31 W to 104 W within 40 seconds of the send, and the host answered over SSH
128 seconds after it. In check mode the module connects to the relay and sends
nothing, and the wait is skipped, so a check run proves the delegation only.

The BMC path was run against pve2 while it was off, on 2026-11-18. With a wrong
password injected as an extra variable, the run failed at the BMC task
(`Incorrect password provided`) and the host stayed off. The check run predicted
the change and left the host off. The real run reported the change after 5
seconds, and the host answered over SSH 133 seconds after the start of the run.
A check run with the host on reported no change.

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

## The node role on the Proxmox nodes

The node playbook targets every host, and its default-on stacks were written for
the Debian workload hosts, so the Proxmox nodes group declares the differences
in its group variables (`group_vars/home_lab_proxmox_nodes`):

- `security_ssh_permit_root_login: prohibit-password`. The nodes are reached as
  root with the lab key, as is Proxmox's own inter-node SSH, so the SSH stack's
  hardening keeps a key-only root login and turns password authentication off.
  The role defaults (`PermitRootLogin no`, `AllowUsers` limited to
  `ansible_user`) assume a non-root login user, and on a host where
  `ansible_user` is root they reject the next login while the run that wrote
  them finishes green, since sshd keeps its established sessions through a
  restart. Two guards in `tasks/ssh.yaml` close that class: an assertion fails
  the host before any edit when the policy would reject `ansible_user` (root
  login forbidden while the user is root, or the user missing from a non-empty
  `AllowUsers`; `AllowGroups` membership is not checked, since the run does not
  read it), and every `sshd_config` edit is validated with `sshd -t` on the
  candidate file, its `Include` resolved against the real drop-in directory, so
  a value sshd rejects fails the task instead of reaching the restart. The
  Molecule instance runs as root with the same variable.
- `configure_monitoring_apt: false` and `configure_monitoring_sata: false`. The
  monitoring role installs Debian's `prometheus-node-exporter-collectors` on the
  nodes, whose apt and SMART timers already write the series the alerts read;
  the node role's own collectors would write the same series a second time into
  the same directory. The apt success stamp the apt collector reads follows
  `configure_monitoring` instead of the apt stack's flag: both roles deploy the
  identical file, and a node run must not remove what the monitoring run put
  there.
- `monitoring_textfile_collector_directory: /var/lib/prometheus/node-exporter`,
  the packaged exporter's directory, where the restic jobs already write: the
  role's static metrics (the expected mounts) are rendered where they are
  scraped. The variable is a role default so that the inventory can override it;
  a role variable would win over the group.
- `security_unattended_upgrades_enabled: true`, the role default made explicit.
  The tool's default origins are Debian stable and Debian security for the
  release, and the role adds the patterns of
  `unattended_upgrades_origin_patterns` in its `vars/main.yaml`: the release's
  updates and backports suites on every host, and the Docker, Tailscale, and
  Raspberry Pi repositories where `configure_docker`, `configure_tailscale`, and
  `is_raspberry_pi` are set. A repository a new stack adds needs an entry there,
  or its upgrades wait for the `AptUpgradesPending` alert. The Proxmox
  repository has no entry, so pve-manager, the kernel and ZFS upgrade through
  the OS packages playbook, as the
  [Linux administration notes](../operations/linux-administration.md#os-package-upgrade)
  describe: it runs the full upgrade that Proxmox prescribes (`apt upgrade` can
  leave its packages partially upgraded, and unattended-upgrades has that
  command's semantics by design: it holds back any step that would remove a
  package). The same holds for a covered origin on any host: an upgrade that
  needs a removal stays pending until that playbook runs, and reaches the alert
  (on raspberrypi2 the camera libraries of Raspberry Pi OS, whose new library
  package replaces the installed one, 2026-11-20). An unattended Docker engine
  upgrade restarts the daemon and containerd under the workloads, which keep
  running because the daemon is configured with `live-restore` (hl01 and
  raspberrypi2 on 2026-11-20, from 29.9.3 to 29.10.0, with every container's
  start time unchanged). Two other origins act on more than packages, with
  nobody reading the release first: the Raspberry Pi origin carries
  `rpi-eeprom`, whose boot-time update service flashes a new bootloader image
  only onto a bootloader older than the minimum the package sets, as the
  [network boot spec](../../architecture/network-boot.md) describes
  (raspberrypi2 on 2026-11-20, from 28.33 to 28.37, with the 2026-10-30 image
  reported as available over the 2026-09-23 one, which two reboots on 2026-11-26
  left in place), and a Tailscale upgrade restarts `tailscaled` on the host that
  advertises the subnet routes (raspberrypi2 on 2026-11-20, five seconds after
  the package was unpacked; the effect on the connections through those routes
  was not measured). The package also installs the kernel hook that sets the
  reboot-required flag, which the `RebootRequired` alert reads.

The containerized exporters of the monitoring stack (the compose file, its
directory and its project unit) follow
`configure_monitoring and configure_docker`, so a host without Docker gets the
host-side collectors alone. The nodes run Debian's packaged node exporter, which
the monitoring role installs: its playbook, `monitoring.yaml`, has no enablement
flag, so a run is limited to the nodes group (the Debian workload hosts run the
containerized exporter on the same port). The packaged unit takes its arguments
from the `ARGS` line of `/etc/default/prometheus-node-exporter`, which the role
owns whole (an argument added by hand on a node is gone at the next run, so
another argument goes into the role's task) and sets to enable the restart
counts of the systemd collector, as the compose template does for the
containerized exporter and the Nix `monitoring` role for the NixOS hosts: an
exporter configured in a fourth place needs the flag too, or
`NodeSystemdMetricsMissing` reports it. The kernel command line of the nodes is
the Proxmox role's: a dictionary of option name to value
(`proxmox_kernel_command_line_options`, the IOMMU options in the group
variables) merged into the line the host boots with, the declared options
replacing the ones of the same name and the rest kept, written to
`/etc/kernel/cmdline` with `proxmox-boot-tool refresh` where
`/etc/kernel/proxmox-boot-uuids` exists (pve1: ZFS root, systemd-boot) and to
`GRUB_CMDLINE_LINUX_DEFAULT` in `/etc/default/grub` with `update-grub` otherwise
(pve2: LVM root, GRUB), followed by a reboot. A host that already carries the
options is left alone, whitespace included; the Molecule instance has neither
file and skips both writes, and the VFIO module task is tagged out of the tests,
since the test container shares the control machine's kernel.

Both nodes had their first full node run (pve1 on 2026-11-10, pve2 on
2026-11-16), each after the OS packages playbook and a reboot, and each followed
by a second check run that predicted nothing. The GRUB branch of the kernel task
first ran on pve2 the same day: the line went from `quiet` to
`quiet intel_iommu=on iommu=pt`, and after the reboot the kernel log reports the
IOMMU enabled with passthrough as the default domain type.

The exclusive set applies to every host, not only Proxmox nodes: keys added by
hand on a host (hardware security keys, for example) disappear at the next
bootstrap run unless the repository declares them. The user and key tasks carry
the `authorized-keys` tag, so a host whose OS tasks cannot run yet (raspberrypi2
on Debian 11, whose release has no `non-free-firmware` component) still gets its
keys converged with `--tags authorized-keys`; on a Proxmox node pair it with
`proxmox`, which registers the node's own key.

## Testing with Molecule

The [operational scripts guide](./operational-scripts.md) describes how to run a
test and what the scenario's two instances are. This section describes what the
tests cover and why they have this shape.

### What the workflow runs

The `Test Ansible collections, roles, playbooks` workflow runs `molecule test`
for each playbook of its matrix, in a job of its own, on pull requests and on
pushes to the default branch, as the
[GitHub Actions guide](./github-actions.md#triggers) describes for every
workflow.

Every playbook has a job although `main.yaml` imports most of them, because a
production run applies the narrowest playbook for a change. A play of `main`
runs after the plays before it in the same process, with the variables their
roles loaded through `include_vars` and the facts they set, so a role that reads
another role's variable passes in `main` and fails on its own. `main` does not
import `boot-bare-metal`, `gateway-dnsmasq`, `monitoring`, `restore-workloads`,
and `update-os-packages`: their jobs are their only test. Reducing the matrix to
`main` and the playbooks it does not import was considered on 2026-11-19 and
rejected: it would halve the job time of a run without shortening the run, since
`main` is the longest job, and remove the only test of the other playbooks on
their own.

Each job builds the Ansible container image from a build cache the jobs share.
The build step takes 31 to 71 seconds while the cache is warm and 184 to 278
seconds in every job after a change to the image's inputs, when all the jobs
build at once (both measured on 2026-11-19; three commits changed those inputs
in the sixty days before). Building the image once in a job the matrix waits for
was considered the same day and rejected: it adds a job and its delay to every
run to shorten the few runs that follow such a change.

### Scenario playbooks named after a playbook

Molecule prepares the fresh instances with the scenario's `prepare.yml`,
converges the playbook under test, and has no verify playbook. A playbook that
needs something else brings its own, named after it in the scenario directory,
which `scripts/run-ansible.sh` selects when they exist: `prepare-<name>.yml`
when it needs more on the instances than a fresh host has, `converge-<name>.yml`
when it requires extra variables, which the wrapper sets while importing it, and
`verify-<name>.yml` for what the three passes cannot assert. Molecule passes
`ANSIBLE_TEST_TAGS` to the verify playbook as well, whose tasks are untagged: a
scope without `untagged` runs none of them and the step still passes (seen with
a scope that selected nothing, 2026-11-19), so a scoped test asserts something
only when its scope includes `untagged`.

- `home-lab-node` has a prepare playbook that applies the bootstrap and
  container engine playbooks first. The node playbook runs on hosts that got
  both before it, and it calls Docker wherever `configure_docker` is set: on a
  fresh instance its idempotence pass fails at the first Compose command. The
  prepare run is a process of its own, so the test is the node playbook alone on
  a prepared host, which is how a production run applies it.
- `gateway-dnsmasq` has a prepare playbook that makes the instance stand in for
  the gateway and a verify playbook that checks what the role wrote to it, as
  [the gateway role](#the-gateway-role) describes.
- `restore-workloads` has all three. The prepare playbook applies the bootstrap
  and backup playbooks, writes a file under the configuration tree, and takes a
  snapshot with the job script, as the role initializes a repository (the job
  unit hides `/tmp`, where the test repository lives, behind a private one). The
  converge wrapper sets the target host and that file's directory as the paths
  to restore, so the three passes are dry runs. The verify playbook changes the
  file, runs a real paths restore, and asserts that the file holds the
  snapshot's content again; the assertion failed in a run with the restore
  turned off (2026-11-19). The Compose stop and start of a stack restore, a
  restore from another host's repository, and the unit restarts stay untested:
  they carry the `molecule-notest` tag or need a second repository.
- `proxmox-node` has a prepare and a verify playbook for the cloud-init snippets
  of the Proxmox role, which the role renders only when they are absent, as the
  [Proxmox administration notes](../operations/proxmox.md#a-changed-cloud-init-snippet-provisions-the-vm-again)
  explain. The scenario declares two VMs for the node-shaped instance; the
  prepare playbook seeds the user data of the first, and the verify playbook
  asserts that the seed is intact and what the role rendered for the other. The
  assertion on the seed failed in a run with the setting removed (2026-11-26).
- `update-os-packages` has a verify playbook for the guards of the
  [OS package upgrades spec](../../architecture/os-package-upgrades.md), which
  must fail a run, and a failed play cannot be caught by the playbook that
  imports it. A fixture script puts a removal in the upgrade plan of the first
  instance (dummy packages in a local repository), and the playbook runs through
  `ansible-playbook` commands on the controller, with the inventory and the
  configuration that Molecule exports to the playbooks it runs
  (`MOLECULE_INVENTORY_FILE`, `ANSIBLE_CONFIG`). The assertions read the exit
  status, the output, and the packages on the instance, for six runs: in check
  mode (the failure is reported and the second instance is reviewed; it is the
  first run after the fixture, so the guard fires only when the check run
  refreshes the lists), without an approval (the guard fails the first instance
  and the second never starts), with an approval for both instances (the
  one-host rule fails the run), with an approval for one (the upgrade removes
  the package), and two with the reboot-required flag set on the second
  instance, where stand-ins for `pvesh` and `zpool` answer that the node has no
  guest and no pool: in check mode (the flag is reported and nothing reboots)
  and for real (the run fails before the silences and the reboot, since the
  first instance, the only monitoring replica of the test inventory, runs no
  Alertmanager). With the `debug` callback the task results are on the standard
  output and the failure messages on the standard error.

### The bootstrap role runs once per playbook run

The container engine, Proxmox node, and Coral playbooks import the bootstrap
playbook so that each can run on its own, and `main.yaml` imports all of them
after the bootstrap playbook itself, which ran the bootstrap role four times per
host in every `main` run, in production as in the tests. The role now sets a
fact as its last task, and the bootstrap play skips the role on a host that
carries it: the first import runs the role and the later ones skip its tasks.
The fact lives for one playbook run, so every run still bootstraps once. The
role's handlers inherit the same condition, so the role flushes them right
before it sets the fact: a handler left for the end of the play would be skipped
without a word, the reboot one included (a scratch role on ansible-core 2.21
showed it, 2026-11-19). A task that notifies a handler therefore never goes
after that flush.

That one run takes 20, 33, and 14 seconds of the three passes of a `main` test
(2026-11-19). On a converged host its apt tasks account for about 5 of those
seconds and its repository tasks for about 3: the role's tasks are untagged, so
this is what a tag-scoped run of `main` still pays. Merging the apt tasks or
tagging the role was not worth that; the node playbook on its own does not
import the bootstrap playbook.

### Where the time goes

A `main` test on the workstation, against the Debian 13 image:

| Pass        | 2026-11-18 | 2026-11-19, bootstrap once | 2026-11-19, deletions read first |
| ----------- | ---------- | -------------------------- | -------------------------------- |
| Check       | 4:15       | 3:09                       | 2:55                             |
| Converge    | 7:21       | 6:36                       | 6:43                             |
| Idempotence | 3:38       | 3:06                       | 2:47                             |

The converge of the middle column comes from a `molecule converge` on fresh
instances rather than from the full test, whose converge stalled for 21 minutes
while the workstation was suspended. The deletion change shows in the check and
idempotence passes; the converge, where the package installs dominate, stayed
within its variation from run to run.

The bootstrap role went from 80, 64, and 45 seconds per pass to 18, 37, and 15.
In the workflow, the same passes took 3:24, 5:58, and 3:12 on 2026-11-18, before
both changes, and the whole run 37 job-minutes over nine jobs.

The node role applies the stacks' directories, templates, copied files, and
deletions in four loops, one module execution per item, which took about 70
seconds of every pass. A host declares absent every path of the stacks it turns
off, so on a converged host most of those executions confirmed that a path was
still missing: 77 files and most of the 57 directories on the instance with
every stack off. One read before each of the two loops that delete now lists the
declared paths that exist, and the loops run the module for those only, which
removed the 20 seconds of the file deletions and a few of the directory loop.
The scenario's `prepare.yml` creates a directory and a file the role declares
absent, and the verify playbooks of `main` and `home-lab-node` assert that the
converge removed them, since a fresh instance has nothing to delete (the
assertion failed in a run with the read returning nothing, 2026-11-19). The
check is for unscoped runs: a tag-scoped converge deletes the paths of the
selected stacks only, so the playbook ends early when `ANSIBLE_TEST_TAGS` is
set.

What remains is about 50 seconds per pass in the three loops that create: each
template or copied file costs two module executions on an unchanged host (a read
of the destination and a check of its attributes), which the modules need for
the per-item results the handlers read. Each of the other tasks costs a fraction
of a second whatever it does. Neither has a known lever.

A test instance image with the role's packages already installed was considered
on 2026-11-19 and rejected. The package installs take about 125 seconds of a
converge on the workstation and 52 in the workflow, but the check pass exists to
run on an instance without them, as a first check run on a fresh host does, and
the iteration loop of the operational scripts guide already pays them once per
set of instances.

## Copy Jinja templates as they are

If you need to copy Jinja templates with the Ansible Template Module, you can
configure Ansible to change the variable start and end prefixes inside the
template by adding a special header.

For example:

```yaml
#jinja2:variable_start_string:'[%', variable_end_string:'%]'
```

Changes the default variable start and end prefixes from `{{` and `}}` to `[%`
and `%]`.

## Linting with ansible-lint

The lint run of the [operational scripts guide](./operational-scripts.md)
includes ansible-lint. Super-linter starts it in `config/ansible`, the
`ANSIBLE_DIRECTORY` of `config/lint/super-linter.env`, with
`config/ansible/.ansible-lint.yml`:

- The configuration file is in `config/ansible`, and not with the other linters'
  files in `config/lint`, because ansible-lint takes the directory of its
  configuration file as the project. From there it finds the roles beside the
  playbooks and installs the role and the collections that `requirements.yml`
  pins, so that it checks the arguments of their modules against the versions
  the playbooks run with. `ANSIBLE_CONFIG_FILE` in the environment file
  therefore holds a path relative to `config/lint`.
- The requirements go to the directory that `ANSIBLE_HOME` names in the
  environment file, inside the linter's container, so every run downloads them
  from Ansible Galaxy (43 MB, about a minute), and the lint, in CI as well,
  fails while Galaxy does not answer. Without that setting ansible-lint keeps
  them in `config/ansible/.ansible`, where the next lint run's other linters
  read the collections as part of the repository: EditorConfig, Gitleaks,
  codespell, and Trivy failed on them (2026-11-26).
- The configuration skips the rule that asks for the whole role name as the
  prefix of a role's variables, since the roles prefix them with the name
  without its `ferrarimarco_home_lab_` part, and gives a value to the variable
  that the restore playbook takes its hosts from.
- A task that keeps a pattern a rule flags carries a `noqa` comment for that
  rule on its name line, with the reason in the comment above the task.
- The fix mode of the lint script passes `--fix` to ansible-lint, which rewrote
  no file in a run on a copy of the tree, with and without findings
  (ansible-lint 26.8.0, 2026-11-26).

ansible-lint does not fail on a playbook it cannot load: it logs
`Failed to load <playbook> playbook due to failing syntax check` and goes on, so
a passing run can have linted less than it seems. Until 2026-11-26 the directory
setting named a path that no longer existed and the linter ran on nothing; then,
with its configuration in `config/lint`, it ran without the collections and
skipped seven playbooks that way. After a change to these settings, check that
the lint summary has the `ANSIBLE` row, and read the linter's own output for
those lines and for the one that names `config/ansible` as the project root:
when super-linter does not find the configuration file it takes its own default
without a word, and ansible-lint then names another directory. Two are expected,
both for `../../playbooks/restore-workloads.yaml`: ansible-lint checks a
playbook that another imports without the configured extra variables, and that
playbook, which the two Molecule wrappers import, has no default for its hosts;
it is linted under its own name. To run the linter alone, as super-linter does:

```shell
docker run --rm --entrypoint /bin/bash \
  --volume "$(pwd)":/tmp/lint:ro --workdir /tmp/lint/config/ansible \
  --env HOME=/tmp/home --env-file config/lint/super-linter.env \
  ghcr.io/super-linter/super-linter:<version> -c \
  'mkdir -p /tmp/home && git config --global --add safe.directory /tmp/lint \
  && ansible-lint -c /tmp/lint/config/ansible/.ansible-lint.yml'
```

On the control machine the run also reads the vault files, which are not in the
repository, and warns that it cannot decrypt them.

## Check mode conventions

- Always run `--check --diff` (capturing the full output to a log file) and
  review the predicted changes before applying. Watch specifically for
  unexpected `state: absent` predictions (see enablement flags above).
- Every download entry declares a `checksum` (`sha256:<hash>`) next to its URL
  pin. With it, `ansible.builtin.get_url` reports an unchanged destination
  without a request, in check mode too; without it, check mode always predicts a
  change, since its HEAD request carries no content to compare. A pin moved
  without a new hash fails the download instead of deploying unverified content.
- The apt module does not refresh the package lists in check mode (read in its
  source at ansible-core 2.21), so the OS packages playbook refreshes them in a
  task of its own that runs in both modes: a check run on a host that was off
  simulates the upgrade against what the repositories hold now (pve2's lists
  were 25 days old on 2026-11-16). With `--diff`, that check run prints apt's
  simulated upgrade, the removals included, the verdict of the removal guard
  that the [OS package upgrades spec](../../architecture/os-package-upgrades.md)
  describes, and the state of the reboot-required flag: the review a manual
  `apt full-upgrade --simulate` would give, and whether a reboot follows.
- Design tasks so check mode runs cleanly and truthfully on first runs:
  state-query tasks carry `changed_when: false` and `check_mode: false`, and
  later tasks tolerate resources that an earlier task would have created.
- A change for a release no host runs yet (the role's Raspberry Pi OS specifics
  ahead of a re-image) is check-run against the network boot rescue system of
  that release, as the [network boot guide](../operations/network-boot.md)
  describes, since the Molecule instance is a generic Debian image.

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
