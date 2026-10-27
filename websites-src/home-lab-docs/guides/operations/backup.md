# Backup operations

Procedures for the restic backups of the Debian hosts and of the Proxmox nodes:
inspecting a repository, restoring, running the drill, repairing. The
[Backups specification](../../architecture/backups.md) describes what is backed
up, where, and what each check proves.

## Where things are

One repository per host at `/media/backup-0/<host>/restic-backup-workloads` on
the nas-pve1 `backups` share, with the drill's scratch directory next to it. The
restic binary exists only inside the job container, built from
`/etc/ferrarimarco-home-lab/restic/`, whose `compose.yaml` (root only) holds the
password: every operation below is a `docker compose run` of that container, so
Docker and the share mount must be up. The job's textfile metrics
(`restic-<job>.prom` in the node exporter textfile directory) carry the
repository identity, the last completed run, the read cycle length, the last
success of each step (`backup`, `check`, `check-read-data` with its group,
`prune`, `restore-drill`), and the drill's file count.

Shorthand used below, run on the host:

```shell
restic_run() {
  sudo docker compose --file /etc/ferrarimarco-home-lab/restic/compose.yaml \
    --profile restic-backup-job run --rm --entrypoint restic \
    restic-backup-workloads "$@"
}
```

## The node job

The Proxmox nodes back up the NAS containers' state directories with the
`restic-backup-nas-state` job of the backup role, which runs the same script
from the packaged restic binary, with no container and no share mount: on pve1
the repository is `/rpool-sata/backups/pve1/restic-backup-nas-state` on the
local dataset, with the drill's scratch directory next to it, and the job's
environment (repository, password, backup set, drill settings) is
`/etc/ferrarimarco-home-lab/restic-native/restic-backup-nas-state.env`, root
only. The metrics land in the packaged node exporter's textfile directory,
`/var/lib/prometheus/node-exporter`. Shorthand, run as root on the node:

```shell
restic_nas_run() {
  sh -c 'set -a; . /etc/ferrarimarco-home-lab/restic-native/restic-backup-nas-state.env; exec restic "$@"' restic "$@"
}
```

The script's restore mode runs through `systemd-run`, which reads the same
environment file the units read, so the space guard and the file count checks
apply; a restore in place needs the container stopped first (`pct stop <id>`),
since Samba, Syncthing, and Tailscale rewrite their state while running:

```shell
systemd-run --wait --pipe --collect --quiet --unit restic-backup-nas-state-restore \
  --property EnvironmentFile=/etc/ferrarimarco-home-lab/restic-native/restic-backup-nas-state.env \
  --property CacheDirectory=restic-native \
  --setenv RESTIC_RESTORE_SNAPSHOT=latest \
  --setenv RESTIC_RESTORE_INCLUDE=/var/lib/syncthing-state/nas-pve1 \
  --setenv RESTIC_RESTORE_TARGET=/ \
  --setenv RESTIC_RESTORE_DRY_RUN=false \
  /etc/ferrarimarco-home-lab/restic-native/entrypoint.sh
```

Leave `RESTIC_RESTORE_DRY_RUN` at its default to list what the restore would
write, and point `RESTIC_RESTORE_TARGET` at the drill's scratch directory for an
inspection restore. The drill and its timer work as on the Debian hosts
(`restic-backup-nas-state-restore-drill.service`), and the first drill after the
deployment is started by hand the same way.

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
of the restore path always target the scratch directory on the share, as the
drill does; the playbook's dry run proves the command, not the outcome, and is
no substitute for a scratch restore.

### In place, through the playbook

`restore-workloads.yaml` restores a stack's two state trees from a snapshot
through the job container's restore mode. It is a dry run unless told otherwise:
the dry run lists what the restore would write and changes nothing.

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
- `restore_stack` (required): the state directory name.
- `restore_compose_stack`, `restore_compose_service`: the Compose project and
  service that run that state when they differ from the directory name
  (qBittorrent's state belongs to the `qbittorrent-nox` service of
  `media-stack`); only that service is stopped and started.
- `restore_snapshot`: an ID or `latest`.
- `restore_source_host`: an inventory host whose repository to use, for a host
  that lost its own; the playbook mounts that repository and passes its password
  from the vault, as the quoted literal the Compose template renders (the
  repositories were keyed with the quotes included).
- `restore_apply`: `true` for the real restore.

A state tree absent from the snapshot is skipped; the two trees are restored
independently. The restore log is printed at the end; the command itself is
hidden from the Ansible output because it can carry a password. Blast radius:
the service is stopped for the duration, and the restore overwrites the two
subtrees with the snapshot's content without deleting files that exist only on
the host. Verify through the service's own interface afterwards.

### For inspection, through the container

The restore mode takes the snapshot, the path within it, the target, and whether
it is a dry run (the default). The space guard refuses a restore when the
target's filesystem has less free space than the restore size plus 20 percent of
it, and the file count is checked against the snapshot listing (equal into an
empty target, at least the listing in place).

```shell
sudo docker compose --file /etc/ferrarimarco-home-lab/restic/compose.yaml \
  --profile restic-backup-job run --rm \
  --env RESTIC_RESTORE_SNAPSHOT=latest \
  --env RESTIC_RESTORE_INCLUDE=/etc/ferrarimarco-home-lab/<stack> \
  --env RESTIC_RESTORE_TARGET=/var/lib/restic/restore-drill \
  --env RESTIC_RESTORE_DRY_RUN=false \
  restic-backup-workloads
```

The drill's scratch directory (`/var/lib/restic/restore-drill` in the container,
`<share>/<host>/restore-drill-restic-backup-workloads` on the host) is the
ready-made target; empty it afterwards, or the next drill empties it first. Any
other target needs a `--volume` on the run, and a full inspection restore (17 GB
on hl01) needs a scratch share, which no host disk has room for.

### A fresh host after a re-image

In this order: bootstrap, Docker (the container engine playbook), the share
mount (the disks playbook), the restic stack of the node role (it never
re-initializes an existing repository), the in-place restore of each stack with
the playbook, then the node role for the stacks. A host that lost its repository
as well restores from nothing: the second-copy item in the
[specs todo list](../../architecture/README.md#backup) exists for that case. A
Proxmox node restores the NAS container's state directories from its own node
job before the container first starts, through the restore mode above.

## The drill

Monthly, on the first Sunday at 03:00 (`<job>-restore-drill.timer`, persistent),
the job restores one secret-free file of the latest snapshot (`entrypoint.sh` by
default, per job) into the scratch directory with `--verify`, checks the file
count, and empties the directory before and after. Run it by hand with
`sudo systemctl start restic-backup-workloads-restore-drill.service`, which is
also the first step after deploying the stack on a host:
`ResticRestoreDrillMissing` fires for a job that never drilled,
`ResticRestoreDrillStale` after 40 days without success. The job's restic
commands wait up to 30 minutes for a repository lock held by another run.

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

## Repair

A repository that `restic check` reports as damaged (`ResticCheckFailed`, or a
failed nightly job) must be repaired before any restore: follow the command's
instructions (`restic repair index`, `restic repair snapshots`) and the
[restic troubleshooting chapter](https://restic.readthedocs.io/en/stable/077_troubleshooting.html),
through `restic_run`.
