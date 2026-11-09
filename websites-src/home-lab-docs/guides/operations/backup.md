# Backup operations

Procedures for the restic backups of the Debian workload hosts and of the
Proxmox nodes: inspecting a repository, restoring, running the drill, repairing.
The [Backups specification](../../architecture/backups.md) describes what is
backed up, where, and what each check proves.

## Where things are

Every host runs its restic jobs the same way, through the backup role: the
Debian restic package, the job script and one root-only environment file per job
(repository, password, backup set, drill settings) under
`/etc/ferrarimarco-home-lab/restic/`, the job's backup and drill units and
timers, and an exporter service per job. On the Debian workload hosts the
`restic-backup-workloads` job has its repository at
`/media/backup-0/<host>/restic-backup-workloads` on the nas-pve1 `backups`
share, with the drill's scratch directory next to it; the share mount must be up
for every operation below, and the units require it. On the Proxmox nodes the
`restic-backup-nas-state` job backs up the NAS containers' state directories to
a repository on the node's own backups dataset (pve1:
`/rpool-sata/backups/pve1/restic-backup-nas-state`). The job's textfile metrics
(`restic-<job>.prom` in the node exporter textfile directory:
`/var/lib/node_exporter/textfile_collector` on the Debian hosts,
`/var/lib/prometheus/node-exporter` on the nodes) carry the repository identity,
the last completed run, the read cycle length, the last success of each step
(`backup`, `check`, `check-read-data` with its group, `prune`, `restore-drill`),
and the drill's file count.

Shorthand used below, run as root on the host (`sudo -i` on the Debian hosts),
with the job name in `RESTIC_JOB`:

```shell
RESTIC_JOB=restic-backup-workloads
restic_run() {
  sh -c 'set -a; . /etc/ferrarimarco-home-lab/restic/'"${RESTIC_JOB}"'.env; exec restic "$@"' restic "$@"
}
```

## Inspect a repository

```shell
restic_run snapshots
restic_run ls latest /etc/ferrarimarco-home-lab/<stack>
restic_run find <file name>
restic_run stats latest --mode restore-size
```

## Restore

An in-place restore is a recovery action: it overwrites live state with the
snapshot's content (qBittorrent's state on hl01 was rolled back by four hours on
2026-10-14 by a restore run as a rehearsal). Rehearsals, inspections, and checks
of the restore path always target the scratch directory next to the repository,
as the drill does; the playbook's dry run proves the command, not the outcome,
and is no substitute for a scratch restore.

### In place, through the playbook

`restore-workloads.yaml` restores a stack's two state trees on a Debian host
from a snapshot through the job script's restore mode, run by `systemd-run` with
the job's environment file. It is a dry run unless told otherwise: the dry run
lists what the restore would write and changes nothing.

```shell
# Dry run: what restoring qBittorrent's state on hl01 from the latest snapshot would do
ADDITIONAL_ANSIBLE_FLAGS="-e restore_hosts=hl01.edge.lab.ferrari.how -e restore_stack=qbittorrent -e restore_compose_stack=media-stack -e restore_compose_service=qbittorrent-nox" \
  ANSIBLE_PLAYBOOK_FILE_NAME="restore-workloads.yaml" scripts/run-ansible.sh

# The real restore: stops the service, restores both trees, starts the service
ADDITIONAL_ANSIBLE_FLAGS="-e restore_hosts=hl01.edge.lab.ferrari.how -e restore_stack=qbittorrent -e restore_compose_stack=media-stack -e restore_compose_service=qbittorrent-nox -e restore_apply=true" \
  ANSIBLE_PLAYBOOK_FILE_NAME="restore-workloads.yaml" scripts/run-ansible.sh
```

Variables:

- `restore_hosts` (required): the target host; the play refuses to run without
  it, so a restore never fans out.
- `restore_stack` (required unless `restore_paths` is given): the state
  directory name.
- `restore_compose_stack`, `restore_compose_service`: the Compose project and
  service that run that state when they differ from the directory name
  (qBittorrent's state belongs to the `qbittorrent-nox` service of
  `media-stack`); only that service is stopped and started.
- `restore_snapshot`: an ID or `latest`.
- `restore_source_host`: an inventory host whose repository to use, for a host
  that lost its own; the playbook writes that host's repository and password
  (from its job declaration and the shared vault) to a temporary root-only
  environment file, which the run loads instead of the local job's.
- `restore_paths`: a JSON list of paths to restore in place instead of a stack's
  trees, for state outside the stacks: no service is stopped or started.
- `restore_services_to_restart`: a JSON list of systemd units restarted after a
  real restore in either mode (`ssh` after the host keys).
- `restore_apply`: `true` for the real restore.

The host's SSH identity, which the job backs up with the state trees, returns to
a re-imaged host this way (dry run first, then with `restore_apply=true`):

```shell
ADDITIONAL_ANSIBLE_FLAGS="-e restore_hosts=raspberrypi2.edge.lab.ferrari.how -e '{\"restore_paths\": [\"/etc/ssh/ssh_host_rsa_key\", \"/etc/ssh/ssh_host_rsa_key.pub\", \"/etc/ssh/ssh_host_ecdsa_key\", \"/etc/ssh/ssh_host_ecdsa_key.pub\", \"/etc/ssh/ssh_host_ed25519_key\", \"/etc/ssh/ssh_host_ed25519_key.pub\", \"/home/pi/.ssh\"], \"restore_services_to_restart\": [\"ssh\"]}'" \
  ANSIBLE_PLAYBOOK_FILE_NAME="restore-workloads.yaml" scripts/run-ansible.sh
```

Only the host key files come back from `/etc/ssh`, not the directory: an older
release's `sshd_config` and `moduli` must not return, and the node role renders
the SSH configuration. The user's `.ssh` directory comes back whole, with the
authorized lab key and the known hosts (the router's host key among them); the
restored `authorized_keys` replaces the fresh system's, which is safe because
the bootstrap playbook puts the same lab key, the one the control machine
authenticates with, in both.

A state tree absent from the snapshot is skipped; the two trees are restored
independently. The restore log is printed at the end. Blast radius: the service
is stopped for the duration, and the restore overwrites the two subtrees with
the snapshot's content without deleting files that exist only on the host.
Verify through the service's own interface afterwards.

### For inspection, through the script

The restore mode takes the snapshot, the path within it, the target, and whether
it is a dry run (the default). The space guard refuses a restore when the
target's filesystem has less free space than the restore size plus 20 percent of
it, and the file count is checked against the snapshot listing (equal into an
empty target, at least the listing in place). The run goes through
`systemd-run`, which reads the same environment file the units read, so the
guards apply; the textfile directory is unset so that the run writes no job
metrics:

```shell
systemd-run --wait --pipe --collect --quiet --unit "${RESTIC_JOB}-restore" \
  --property EnvironmentFile=/etc/ferrarimarco-home-lab/restic/"${RESTIC_JOB}".env \
  --property CacheDirectory=restic \
  --property UnsetEnvironment=RESTIC_TEXTFILE_COLLECTOR_DIRECTORY \
  --setenv RESTIC_RESTORE_SNAPSHOT=latest \
  --setenv RESTIC_RESTORE_INCLUDE=/etc/ferrarimarco-home-lab/<stack> \
  --setenv RESTIC_RESTORE_TARGET=/media/backup-0/<host>/restore-drill-restic-backup-workloads \
  --setenv RESTIC_RESTORE_DRY_RUN=false \
  /etc/ferrarimarco-home-lab/restic/entrypoint.sh
```

Leave `RESTIC_RESTORE_DRY_RUN` at its default to list what the restore would
write. The drill's scratch directory (`restore-drill-<job>` next to the
repository) is the ready-made target; empty it afterwards, or the next drill
empties it first. A full inspection restore (17 GB on hl01) needs a scratch
filesystem with room for it. On a node, a restore in place of a NAS container's
state directory (`RESTIC_RESTORE_TARGET=/`, the include being the state
directory) needs the container stopped first (`pct stop <id>`), since Samba,
Syncthing, and Tailscale rewrite their state while running.

### A fresh host after a re-image

In this order: bootstrap, Docker (the container engine playbook), the share
mount (the disks playbook), the backup playbook (it never re-initializes an
existing repository), the SSH identity restore above (the host then presents its
old host key again: clear the control machine's known-hosts entry a second time
and accept it), the in-place restore of each stack with the playbook, then the
node role for the stacks. A host that lost its repository as well restores from
nothing: the second-copy item in the
[specs todo list](../../architecture/README.md#backup) exists for that case. A
Proxmox node restores the NAS container's state directories from its own node
job before the container first starts, through the restore mode above.

## The drill

Monthly, on the first Sunday at 03:00 (`<job>-restore-drill.timer`, persistent),
the job restores one secret-free file of the latest snapshot (the job script on
the Debian hosts, a public cached file on the nodes, per job) into the scratch
directory with `--verify`, checks the file count, and empties the directory
before and after. Run it by hand with
`sudo systemctl start <job>-restore-drill.service`, which is also the first step
after deploying a job on a host: `ResticRestoreDrillMissing` fires for a job
that never drilled, `ResticRestoreDrillStale` after 40 days without success. The
job's restic commands wait up to 30 minutes for a repository lock held by
another run.

## The exporter

`<job>-restic-exporter.service` serves the repository's metrics on the job's
port and runs its own structural `restic check` at every refresh (every twelve
hours). It opens the repository at start and exits on a restic error, so it
stays down, and `ResticExporterDown` fires, while the repository is unreachable;
systemd restarts it after a minute, and the share's mount unit starts it when
the share mounts. Its venv is built at start from the requirements file next to
the job script, so a new exporter release lands with a restart of the unit after
the role rendered the file.

## Re-seed qBittorrent's settings

qBittorrent's settings file (`qBittorrent/qBittorrent.conf` in its configuration
directory) is rendered by the node role as a seed and then owned by the client,
which rewrites it with its own keys. To bring a changed template onto a host
that already has the file: save a copy, stop the client with
`docker compose --file /etc/ferrarimarco-home-lab/media-stack/compose.yaml stop qbittorrent-nox`
(the grace period lets it flush its resume data), move the live file aside, run
the node role for the media stack on the host, start the client the same way,
and compare the file it rewrote against the copy. The torrents and the
categories live in other files and survive; what the re-seed drops is any
setting changed in the web interface that the template does not carry, so read
the copy before deciding.

## Forget a snapshot group

The nightly `restic forget` groups snapshots by host label and tags and keeps
the daily ones within a week of each group's newest snapshot, so a group that
stops receiving snapshots (the Compose-era job of a host switched to the backup
role, which labelled its snapshots with the container's hostname) keeps its last
week forever. The job script forgets and prunes the snapshots named in
`RESTIC_SNAPSHOT_TO_PRUNE`, which is also how the last survivor of a keep policy
goes, since restic never empties a group through a policy. Dry-run first with
the shorthand above, then run the script through the job's environment, as a
restore does; the script prunes without a cache, so restic's warning about a
slow prune is expected:

```shell
# What would go: the IDs of the group, from restic snapshots
restic_run forget --dry-run --no-lock <id> [<id> ...]

sudo systemd-run --wait --pipe --collect --quiet --unit "<job>-forget" \
  --property EnvironmentFile=/etc/ferrarimarco-home-lab/restic/<job>.env \
  --property CacheDirectory=restic \
  --property UnsetEnvironment=RESTIC_TEXTFILE_COLLECTOR_DIRECTORY \
  --setenv "RESTIC_SNAPSHOT_TO_PRUNE=<id> [<id> ...]" \
  /etc/ferrarimarco-home-lab/restic/entrypoint.sh
```

The exporter lists the repository every 12 hours; restart its service
(`<job>-restic-exporter.service`) to see the change on the dashboard at once.

## Repair

A repository that `restic check` reports as damaged (`ResticCheckFailed`, or a
failed nightly job) must be repaired before any restore: follow the command's
instructions (`restic repair index`, `restic repair snapshots`) and the
[restic troubleshooting chapter](https://restic.readthedocs.io/en/stable/077_troubleshooting.html),
through `restic_run`.
