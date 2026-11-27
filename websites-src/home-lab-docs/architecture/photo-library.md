# Design Spec: Photo Library

## Implementation Status

| Component / Feature             | Status      | Details                                                                                                                                                   |
| :------------------------------ | :---------- | :-------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Staging dataset and share**   | **Missing** |                                                                                                                                                           |
| **Google Photos exports**       | **Missing** | One export per account; none requested yet.                                                                                                               |
| **Photo guest (`photos-pve2`)** | **Missing** | Waits on the fleet's move to NixOS 26.11 ([Host configuration](./README.md#host-configuration)).                                                          |
| **Database dump**               | **Missing** | Whether Immich's own dump job runs with the database role the NixOS module creates is unverified; the [rollout item](./README.md#backup) names the check. |
| **Imports and export checks**   | **Missing** |                                                                                                                                                           |
| **Phone backup**                | **Missing** |                                                                                                                                                           |
| **Library backup job**          | **Missing** |                                                                                                                                                           |
| **Offsite copy**                | **Missing** | Waits on the destination of the [Backup](./README.md#backup) todo items.                                                                                  |
| **Monitoring**                  | **Missing** |                                                                                                                                                           |

## Goal

Make the lab the complete repository of the household's photos and videos: an
[Immich](https://github.com/immich-app/immich) server that the phones back up
to, with a second copy on another host and a third outside the home, and bring
in what exists today with checks that bound what can be lost on the way.

## Scope

What goes into the library, where the server runs and why, how the existing
photos are exported and checked, how the phones back up, where the copies are,
and what is monitored. The procedures (the export request, the import commands,
the phone setup) belong in an operations guide written with the rollout.

Account names, people's names, and directory names that carry them stay out of
the repository.

## What goes into the library

- The Google Photos libraries of the household's Google accounts: about 200 GB
  in total, backed up at original quality (stated on 2026-11-23).
- About 100 GB of files on a machine outside the lab, which are not in Google
  Photos.
- From then on, what the Android phones capture.

The library is the complete repository, and Google Photos becomes a convenience
copy (decided on 2026-11-27): the phones keep uploading to it, and it may hold
less than the library, because items are deleted there to stay within the
storage quota. Two rules govern those deletions:

- An item is deleted from Google Photos only once the library and a snapshot of
  the library backup job hold it. For the items of an export, that is once the
  account's export checks have passed and a snapshot taken after the import
  exists. An item picked by hand is first found in the library, by its date and
  by viewing it, and the newest snapshot must be more recent than its upload
  there.
- Nothing is deleted in bulk (a year, an album, the result of a search) before
  the offsite copy of [Copies and backup](#copies-and-backup) exists: until
  then, Google Photos is the only copy outside the home of what it holds.

The first rule also protects the files of the other machine: its disk is not
reused before their import is checked and a snapshot holds them.

Turning the Google Photos backup off on the phones was rejected (2026-11-27). It
would remove the cases of [Phone backup](#phone-backup) that leave an item in
Google Photos alone, but the household keeps Google Photos for its convenience.

## Why Google Takeout

No Google Photos API returns a complete library:

- Since 2025-03-31 the Library API lists and returns only the items the calling
  application created
  ([API updates](https://developers.google.com/photos/support/updates)), and the
  Picker API returns what a person selects by hand.
- A photo downloaded through the API keeps its metadata "except the location
  metadata", and a video comes as "a high quality, transcoded version of the
  original"
  ([access media items](https://developers.google.com/photos/library/guides/access-media-items)).

[Google Takeout](https://support.google.com/accounts/answer/3024190) is
therefore the export path. Three of its properties shape the import:

- What was edited in Google Photos (dates, locations, descriptions, favorites,
  album membership) is in a JSON sidecar file beside each media file, not in the
  media file.
- An album is a folder holding copies of files that the year folders also hold.
- An archive carries no manifest and no item count, and it expires about seven
  days after it is created.

## Placement

Immich runs as a NixOS module in an unprivileged NixOS LXC container on pve2,
`photos-pve2`, built on the [NixOS LXC framework](./proxmox-lxc.md): the
`common` and `comin` roles, a `photos` role, and a container resource in the
workloads Terraform stack. The container is sized at Immich's documented
recommendation, 4 cores and 8 GB of memory
([requirements](https://docs.immich.app/install/requirements)), with machine
learning enabled and no acceleration device.

The server is available while pve2 is on, by decision (2026-11-23): a phone
whose backup finds no server keeps its photos and uploads them at the next
opportunity. Whether pve2 runs around the clock stays the open question the
[host power guide](../guides/operations/host-power.md#pve2) records.

The module needs no secret: with its default local database and cache, both
reached over Unix sockets, it asks for a secrets file only when the database is
remote (read in the module at the nixpkgs revision of 2026-11-22 that the flake
locks, on the 26.05 branch). The Immich accounts and their API keys are created
in the web interface and live in the database.

Decisions:

- **pve2, not pve1.** pve1 had about 1 GB of its 16 GB of memory available on
  2026-11-22, against Immich's minimum of 6 GB. pve2 had 122 GB of memory free
  and 3.5 TB free on `tank-hdd`.
- **A NixOS module, not the Compose stack.** Docker Compose is the deployment
  upstream supports, and it would run on a Debian host: on hl01, which is on
  pve1, or on a new Debian guest, while the lab's direction is away from Debian
  hosts.
- **Its own container, not the NAS container.** The NAS containers are
  privileged, and a web service that parses media files uploaded by every phone
  does not belong in a privileged container.
- **Unprivileged.** The library dataset serves this guest alone, so its mount
  point is owned by the service user's UID as the node sees it (the pinned guest
  UID plus the container's ID map offset), and no other consumer has to agree on
  the ownership. This is the case the framework's privileged opt-in does not
  cover.
- **A container, not a VM.** A bind-mounted dataset keeps the library on the
  node's ZFS, where the node's backup job reads it; in a VM the library would
  sit in a virtual disk, out of that job's reach, on a filesystem stacked on
  ZFS. Upstream recommends a full VM for its Docker deployment and advises
  against Docker in LXC, which a native service does not use; whether the
  module's hardened units start in an unprivileged container is checked first in
  the rollout, and a VM is the fallback.
- **NixOS 26.11, with the fleet.** Immich 3 is in no stable NixOS release before
  26.11: 25.11 and 26.05 carry 2.7.5, which 26.05 marks as no longer updated. A
  second nixpkgs pin for this guest alone was rejected as a mechanism for a gap
  of weeks.

## Storage

| Data                                   | Where                                                         | Replaceable                            |
| :------------------------------------- | :------------------------------------------------------------ | :------------------------------------- |
| Originals, profile data, database dump | `tank-hdd/photos`, bind-mounted as Immich's media location    | No                                     |
| Thumbnails and transcoded videos       | The same dataset                                              | Yes: Immich regenerates them           |
| Postgres data directory                | A state directory on pve2's root disk (NVMe), bind-mounted    | Yes: restored from the dump            |
| Machine learning model cache           | The container's root filesystem                               | Yes: downloaded again                  |
| Takeout archives, files to import      | `tank-hdd/photos-import`, a `photos-import` share on nas-pve2 | Yes, while the sources still hold them |

- The database stays off the library's hard disk and off any network share, as
  the Immich requirements ask. The state directory follows the pattern of the
  NAS containers' state directories
  ([NAS LXC Container](./nas-lxc-container.md)), so it survives a container
  recreation.
- A database dump is written every day into the media location, so one dataset
  holds everything a restore needs: the originals and the metadata.
- The storage template is enabled before the first import, with Immich's default
  layout (`Year/Year-Month-Day/Filename.Extension` under a directory per user),
  so the originals stay readable without Immich and its database.
- The staging dataset and its share follow the three coupled declarations of a
  [per-host share](./nas-lxc-container.md#51-adding-per-host-shares). The photo
  guest reads the dataset through a read-only bind mount, so an import does not
  cross the network.

## Exports and imports

Each Google account is handled on its own, one after the other, because an
archive expires in about seven days:

1. Items in the Locked Folder that must be kept are moved out of it: Google's
   [transfer documentation](https://support.google.com/accounts/answer/9666875)
   excludes them, and the export is assumed to do the same.
2. The export is requested for Google Photos alone, with every album and every
   year, as ZIP parts of 50 GB, delivered as download links. Delivery to Google
   Drive is not an option: Drive shares the storage quota that is nearly full.
3. The parts are downloaded to the staging share, in a directory per account,
   and stay there after the import as the reference: the sidecar files hold what
   an import tool may not apply.
4. Checks 1 and 2 below run on the archives. They need no server, so they can
   run before the guest exists.
5. The archives are imported into that person's Immich account with
   [immich-go](https://github.com/simulot/immich-go), the tool the
   [Immich documentation](https://docs.immich.app/features/command-line-interface)
   recommends for Takeout, in a release that supports the server's major version
   (0.32.0 for Immich 3), first as a dry run. The import applies the sidecar
   files and recreates the albums. It includes archived items and the media
   files that have no sidecar, and leaves out trashed items and items shared by
   a partner, which the partner's own export carries.
6. Checks 3 to 5 run, and the results go into a record kept beside the archives.

The files from the other machine are copied to the staging share and imported as
a folder into their owner's account; check 3 applies to them.

## Export checks

No single check proves that an export is complete, at full resolution, with its
metadata. Each account passes these, in order:

| Check                | Passes when                                                                                                                                               | Does not prove                                     |
| :------------------- | :-------------------------------------------------------------------------------------------------------------------------------------------------------- | :------------------------------------------------- |
| 1. Archive integrity | Every part the export page lists is present and every ZIP passes its integrity test                                                                       | That Takeout put every item in the archive         |
| 2. Pairing           | Every sidecar file has its media file in the archive; the media files with no sidecar are listed                                                          | Anything about an item missing with its sidecar    |
| 3. Import accounting | The account's asset count equals the distinct media files of the archive (by content hash), minus the files the record lists as left out, with the reason | That the metadata arrived                          |
| 4. Byte identity     | The phone's app, at its first backup, skips the files that predate the export; each one it wants to upload is examined                                    | Anything about items that are on no device anymore |
| 5. Metadata          | Every album has its item count, the favorites have theirs, and a sample of items edited in Google Photos shows the edited date, location, and description | That every item's metadata arrived                 |

Check 4 uses the app's deduplication: it computes a checksum of each local file
and skips the ones the server already holds
([mobile backup](https://docs.immich.app/features/mobile-backup)), so a skipped
file is byte-identical to the one Takeout delivered. Whether Takeout returns the
uploaded bytes of an original-quality item is not documented; this check
measures it.

What no check covers: an item that Takeout left out together with its sidecar
and that is on no phone. Only Google Photos still shows it. The lookup that
precedes the deletion of a hand-picked item finds such an item; a bulk deletion
looks nothing up and removes it, with or without the offsite copy, and no check
narrows that.

## Phone backup

- Every person has an Immich account of their own, and the Immich app on their
  phone backs up the camera folder, plus the folders that person selects, over
  Wi-Fi.
- The app is enabled on a phone only after that person's import has passed
  checks 1 to 3, because check 4 is the app's first backup.
- The app reaches the server at the guest's lab name,
  `http://photos-pve2.edge.lab.ferrari.how:2283`, which exists on the home
  network only. The guest takes its address by DHCP on a pinned MAC address with
  a reservation on the gateway, as the other guests do.
- The traffic is plain HTTP on the home network, accepted for this iteration:
  whoever can observe that network can read the uploads and the session. Backup
  away from home and TLS are an idea in the [todo list](./README.md#ideas).
- The Google Photos backup stays enabled on the phones, so each phone runs two
  backup apps, and the [Backup](./README.md#backup) todo items cover the quota.
  Two cases leave an item in Google Photos and not in the library, where a
  deletion in Google Photos then loses it. Neither is covered, beyond the lookup
  that precedes the deletion of a hand-picked item:
    - The Immich backup of a phone stalls, or pve2 is off, and the file leaves
      the phone before the Immich app uploads it, for instance when its owner
      frees the space of what Google Photos has backed up.
    - An item reaches Google Photos without passing through a backed-up folder
      of a phone: an upload from a browser, or an item saved from a shared album
      or from a partner.

## Versions

The guest's Immich version is the one of the fleet's nixpkgs pin. The app on the
phones updates on its own, and it works with the server's major version and the
one before, while the server works only with clients of its own major version
([upgrading](https://docs.immich.app/install/upgrading)); a server upgrade to a
new major version therefore follows the phones' update.

A stable NixOS release keeps the major version it shipped with (observed with
Immich 2 on 25.11 and 26.05), so the server can end up on a version upstream no
longer updates until the next NixOS release. This is accepted (2026-11-23).
nixpkgs marks such a version as vulnerable, which fails the evaluation of the
host, and so the flake check, at the next lock update.

Immich does not support downgrades: after an upgrade that migrated the database,
a rollback of the guest's system also needs the dump taken before the upgrade.

## Copies and backup

| Data                              | Copies                                                                                                                                         |
| :-------------------------------- | :--------------------------------------------------------------------------------------------------------------------------------------------- |
| Items exported from Google Photos | Google Photos, for what is not deleted there; the archives on the staging dataset; the library; the backup repository; the offsite copy        |
| Files from the other machine      | The library; the backup repository; the offsite copy                                                                                           |
| What the phones capture afterward | The phone, until its owner frees the space; Google Photos, for what is not deleted there; the library; the backup repository; the offsite copy |

The backup is a `restic-backup-photos` job of the backup role on pve2, declared
and verified like every job of the [Backups specification](./backups.md), which
holds the verification matrix:

- It covers the originals, the profile data, and the database dumps of the media
  location, and leaves out the thumbnails and the transcoded videos.
- Its repository is on pve1's `rpool-usb-1/backups` dataset, the pool that holds
  the lab's valuable data, so the second copy is on another host and another
  disk. nas-pve1 already exports the dataset as its `backups-usb` share, and
  pve2 mounts it, the way the Debian hosts mount their repository share.
- It keeps monthly snapshots for a year beside the daily ones, through the job's
  own forget policy: a deletion or a corruption that Immich propagates is
  noticed late, long after seven daily snapshots have turned over.
- It runs while pve2 is on.

The offsite copy is a copy of the job's repository at the offsite or cloud
destination of the [Backup](./README.md#backup) todo items, which name no
destination yet. It is made and verified like the second copy of the lab's other
restic repositories, which the same items describe.

Decisions:

- **restic, not ZFS replication.** Replication to pve1 would copy the dataset
  with less work per run, but the repository checks, the pack reads, the restore
  drill, and their alerts exist for restic only, and irreplaceable data is where
  they matter most.
- **A copy outside the home is part of this design.** Google Photos does not
  count as one, because items are deleted there. Until the offsite copy exists,
  every copy the lab holds is in one home, and an item deleted from Google
  Photos has no copy elsewhere.

## Monitoring

- An HTTP probe of the monitoring backends on
  `http://photos-pve2.edge.lab.ferrari.how:2283/api/server/ping`, which answers
  without authentication with a body containing `"res":"pong"`.
- The guest imports the `monitoring` role and joins the NixOS containers group
  of the Ansible inventory, from which the backends derive their scrape targets.
  The group turns the scrape off, because the NAS containers import no
  `monitoring` role, so the guest's host variables turn it on again with
  `enable_prometheus_node_exporter_scraping`. `SystemdUnitFailed` then covers
  the Immich server, the machine learning service, Postgres, and the cache.
- The backup job's rules and exporter come with its declaration in pve2's
  `restic_backup_jobs`, from which the set that the coverage alert expects
  derives.

While pve2 is off, the probe and the backup staleness rules fire, as the node's
own alerts do; whether a host that is off on purpose keeps them firing is the
decision the pve2 BMC item of the
[todo list](./README.md#monitoring-and-alerting) records.

Not covered: a phone that stopped backing up, which Android's battery
optimization can cause without any error on the server. It is an item of the
[todo list](./README.md#monitoring-and-alerting).
