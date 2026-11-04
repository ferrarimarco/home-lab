# Design Spec: Backups

## Implementation Status

| Component / Feature                 | Status                | Details                                                                                                                                                                                                                                                                                                                                                              |
| :---------------------------------- | :-------------------- | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Workloads backup job**            | **Fully Implemented** | Nightly `restic-backup-workloads` job of the backup role over the two state trees of each Debian workload host, seven daily snapshots. The single-flavour role (2026-10-31) runs on hl01 since 2026-11-04 (first native backup and drill clean); raspberrypi2 still runs the former Compose job, unmanaged, until its re-image ([rollout item](./README.md#backup)). |
| **Per-host repositories**           | **Fully Implemented** | One repository per host on the nas-pve1 `backups` share; initialized only by a dedicated role task, implicit initialization refused by the job. hl01's key was rewritten in place with the unquoted password on 2026-11-04; raspberrypi2's repository carries the former quoted password until the re-key of the [rollout item](./README.md#backup).                 |
| **Coverage declaration**            | **Fully Implemented** | `expected_backup_jobs` rendered as a static series; `ExpectedBackupMissing` fires for a declared job that never reported a run.                                                                                                                                                                                                                                      |
| **Exporter per job**                | **Fully Implemented** | One exporter service per declared job, on every host, scraped through targets derived from the same declarations; applied on hl01 on 2026-11-04 (target up), not yet on the nodes. raspberrypi2 declares its exporter off until its re-image, whose Python the exporter release accepts.                                                                             |
| **Structural and pack-data checks** | **Fully Implemented** | Exporter `restic check` every 12 hours; the job reads one group of pack files per night, every pack once per cycle.                                                                                                                                                                                                                                                  |
| **Restore drill**                   | **Fully Implemented** | Monthly drill of one bounded subtree with `--verify` into a scratch directory next to the repository.                                                                                                                                                                                                                                                                |
| **NixOS state backup**              | **Fully Implemented** | `restic-backup-nas-state` job of the backup role on pve1 (the three NAS state directories) and pve2 (the Samba state); applied on pve1 on 2026-10-27 with the former packaged-binary flavour (first backup and drill ran clean, the coverage alert cleared), the single-flavour role not yet applied; pve2 off.                                                      |
| **Second copy of the repositories** | **Missing**           | The repositories exist only on the nas-pve1 share, a single-disk pool; the second copy is a [Backup](./README.md#backup) todo item.                                                                                                                                                                                                                                  |

## Scope

What the backups protect, where the data goes, the decisions behind the layout,
and what each verification mechanism proves and does not prove. The
[backup operations guide](../guides/operations/backup.md) holds the procedures;
the [Monitoring Alerting specification](./monitoring-alerting.md) holds the
alert rules.

## What is backed up

The Debian hosts (hl01, raspberrypi2) run their workloads as Docker Compose
stacks whose state lives in two bind-mounted trees per host, the configuration
tree (`/etc/ferrarimarco-home-lab`) and the runtime tree
(`/var/lib/ferrarimarco-home-lab`), one subdirectory per stack. Those two trees
are the backup set, nightly, through the `restic-backup-workloads` job of the
`ferrarimarco_home_lab_backup` role. Not backed up, by decision:

- Containers and images: disposable, recreated by Compose and re-pulled from the
  registries, which is why the weekly Docker prune removes them freely.
- Docker volumes: no stack keeps state in them, so there is nothing to back up,
  and anything that landed there would be pruned weekly.
- Media: replaceable; a second copy and a nightly manifest are tracked in the
  [specs todo list](./README.md#backup).

The NAS containers' service state (the Samba databases, the Syncthing device key
pair and index, the Tailscale node key) is bind-mounted from directories on the
Proxmox node that runs the container, so the node backs those directories up,
nightly, through the `restic-backup-nas-state` job of the same role. Every job
runs the same way, whatever the host: the Debian restic package, the role's job
script, one root-only environment file per job carrying the repository and its
password, systemd units, and an exporter; the
[Ansible development guide](../guides/development/ansible.md) describes the
role. The index database is rebuildable by a rescan and the synced data is
re-syncable from the remote peer, so the value of that backup is the identities
and the topology, which hold secret material (the
[NAS LXC container specification](./nas-lxc-container.md) lists it). hl02 holds
no state of its own: its configuration is the flake, and the broker's
persistence store is a cache that every consumer republishes on reconnect
([MQTT Broker](./mqtt-broker.md)).

## Where the data goes

Each host owns one restic repository on the nas-pve1 `backups` share (the
`rpool-sata/backups` ZFS dataset on pve1), mounted over CIFS at
`/media/backup-0` as `<share>/<host>/restic-backup-workloads`. pve1 reaches the
same dataset locally, where its `restic-backup-nas-state` repository sits next
to the Debian hosts' ones under its own host directory; pve2's sits on its own
`tank-hdd/backups` dataset. The password is a vaulted variable rendered into the
job's environment file, readable by root on the host only. Retention keeps seven
daily snapshots. The repositories have no second copy: losing the share loses
them (the [second copy of the restic repositories](./README.md#backup) is a todo
item).

Which jobs a host must run is declared, not inferred from what runs: a host's
`expected_backup_jobs` inventory list, or, by default, the restic jobs it
configures, of either flavour. The monitoring backends render that list as a
static series and alert when a declared job has never reported a run from its
host, so a host that holds state but whose job has not run yet (a Proxmox node
before its `restic-backup-nas-state` job is applied) is a standing warning until
the job reports. Every NixOS host declares its list explicitly, empty where the
host holds no state of its own (hl02, and the NAS containers, whose state the
nodes cover), so an undeclared host is a review finding rather than silent
coverage.

Decisions:

- **One repository per host, not one for the lab** (confirmed 2026-10-14). A
  repository is restic's deduplication, locking, and key domain. A shared one
  would deduplicate little (state trees differ per host), would let any host
  forget or prune every other host's snapshots with no append-only protection on
  a CIFS backend, and would serialize the nightly jobs on the repository lock.
  Revisit when a backend with per-client isolation and append-only mode exists
  (restic's REST server on the NAS would qualify).
- **Repositories are created deliberately, never implicitly.** The job refuses
  to initialize a missing repository; the role initializes one only through a
  dedicated task, after checking that the path is not on the host's root
  filesystem (the mount gone means a bare directory on the root disk, which is
  how raspberrypi2 backed itself up to itself in October 2026). The backup unit
  fails, rather than skips, on the same condition.
- **One job flavour on every host, restic from the Debian package**
  (2026-10-31). The former Compose job of the Debian hosts, which ran restic
  from a container image, retired: every host runs the role's units with its
  release's restic package, so a restore on a Debian host needs the share mount,
  not Docker, and a node's restore needs neither. The job script's preflight,
  run by the role after the repository exists, tells with restic's own error
  whether the installed package can run it, so a host whose Debian release ships
  an older package is upgraded (hl01, a
  [Host configuration](./README.md#host-configuration) todo item; the non-Nix
  hosts are meant to share one Debian release) rather than given restic from
  elsewhere: a pinned GitHub release and a package pinned from a newer release
  were both implemented and rejected, the first as a second package manager with
  hashes to verify by hand on every bump, the second as state that drifts from
  the host's release. The job's snapshots carry the machine hostname; the
  Compose job's carried a container hostname, so the repositories of hl01 and
  raspberrypi2 keep a second snapshot group until the
  [rollout item](./README.md#backup) forgets it.

## What is verified, and what is not

| Mechanism                                                                                                               | Cadence                                                                     | Proves                                                                                                 | Does not prove                                                           | Reported by                                                     |
| ----------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------ | --------------------------------------------------------------- |
| Coverage (declared jobs versus jobs that reported a run)                                                                | every evaluation                                                            | every host that holds state has its restic job configured and run at least once                        | that the job keeps running (the staleness rules do)                      | `ExpectedBackupMissing`                                         |
| Backup job                                                                                                              | nightly                                                                     | a new snapshot exists for both trees                                                                   | that the data is readable later                                          | `ResticBackupStale`, `ResticBackupMissing`, `SystemdUnitFailed` |
| Repository identity                                                                                                     | every run                                                                   | the job opened the repository it is meant to use                                                       | anything about the content                                               | `ResticRepositoryChanged`                                       |
| Structural check (`restic check`, by the job and by the exporter)                                                       | nightly, every 12 h                                                         | indices, trees, and snapshot references are consistent                                                 | that the pack files hold intact data                                     | `ResticCheckFailed` (exporter), `SystemdUnitFailed` (job)       |
| Pack data reads (`restic check --read-data-subset=n/t`)                                                                 | one group per night, every pack once per `t` nights (7 by default, per job) | every stored block hashes to what the index says, within `t` nights of being written                   | that a restore works end-to-end                                          | `ResticReadDataCheckStale`, `SystemdUnitFailed`                 |
| Restore drill (one small secret-free file, `--verify`, file count against the listing, target emptied before and after) | monthly, first Sunday                                                       | the restore path works: binary, password, mount, space guard, files restored with content and metadata | that every subtree restores; that the data is intact (the pack reads do) | `ResticRestoreDrillStale`, `ResticRestoreDrillMissing`          |
| Full restore                                                                                                            | manual, before an event that depends on it                                  | everything the drill proves, for the whole state set                                                   |                                                                          | the operator, through the services                              |

The freshness rules read the backup step timestamp every job writes after
`restic backup` succeeded, so a declared job is expected, alerted on when it
never reports, and alerted on when it stops. Every declared job also gets an
exporter and a scrape target from the same declaration, so the exporter rows
(`ResticExporterDown`, `ResticMetricsMissing`, `ResticCheckFailed`) cover it
too, except on a host that declares the exporter off (raspberrypi2 until its
re-image): there the integrity checks are the job's own nightly check and pack
reads, reported by `SystemdUnitFailed` within minutes of a failed run and by
`ResticReadDataCheckStale` when the step stops advancing.

Restic assigns each pack file to a fixed group by its identifier, so new
snapshots and repacks never shift the groups, every pack is read once per cycle,
and a pack is read for the first time at most `t` nights after it is written:
that is the detection latency for silent corruption on the share. The drill is
deliberately small because a full monthly restore would re-read data the pack
reads already verify, at the cost of the full restore size (17 GB on hl01 in
October 2026) on a target that has to hold it; its target is a scratch directory
next to the repository on the share, never the root disk.
