# Design Spec: Photo Library

## Implementation Status

| Component / Feature             | Status      | Details                                                                                                                                                                                             |
| :------------------------------ | :---------- | :-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Staging dataset and share**   | **Missing** |                                                                                                                                                                                                     |
| **Google Photos exports**       | **Missing** | One export per account; none requested yet.                                                                                                                                                         |
| **Photo guest (`photos-pve2`)** | **Missing** | Waits on the fleet's move to NixOS 26.11 ([Host configuration](./README.md#host-configuration)).                                                                                                    |
| **Database dump**               | **Missing** | Whether Immich's own dump job runs with the database role the NixOS module creates, and writes a missed dump after a start, is unverified; the [rollout item](./README.md#backup) names the checks. |
| **Imports and export checks**   | **Missing** |                                                                                                                                                                                                     |
| **Phone backup**                | **Missing** |                                                                                                                                                                                                     |
| **Library backup job**          | **Missing** | Defined in the [Backups specification](./backups.md); the backup role has neither the exclusion nor the guard yet.                                                                                  |
| **Restore rehearsal**           | **Missing** |                                                                                                                                                                                                     |
| **Deletion check**              | **Missing** |                                                                                                                                                                                                     |
| **Offsite copy**                | **Missing** | Waits on the destination of the [Backup](./README.md#backup) todo items.                                                                                                                            |
| **Monitoring**                  | **Missing** |                                                                                                                                                                                                     |

## Goal

Make the lab the complete repository of the household's photos and videos: an
[Immich](https://github.com/immich-app/immich) server that the phones back up
to, with a second copy on another disk and a third outside the home, and bring
in what exists today with checks that bound what can be lost on the way.

## Scope

What goes into the library, where the server runs and why, how the existing
photos are exported and checked, how a deletion in Google Photos is checked, how
the phones back up, where the copies are, and what is monitored. The procedures
(the export request, the import commands, the phone setup) belong in an
operations guide written with the rollout.

What the Google accounts hold besides the photos is not part of this design: a
[Backup](./README.md#backup) todo item has the specification to write for it.

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
storage quota. Three rules govern those deletions:

- An item is deleted from Google Photos only once the library holds its current
  copy and metadata, and a snapshot of the library backup job holds both. The
  [deletion check](#deletion-check) establishes that for every set of items
  before the set is deleted, whether the items were picked one by one or in
  bulk.
- A set chosen in bulk, by a criterion (a year, an album that already existed,
  the result of a search) instead of item by item, is not deleted before the
  offsite copy of [Copies and backup](#copies-and-backup) exists: until then,
  Google Photos is the only copy outside the home of what it holds.
- Nothing is deleted before the first restore rehearsal of
  [Copies and backup](#copies-and-backup) has passed.

The files of the other machine are protected in the same way: its disk is not
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
- Takeout documents no manifest and no item count for an archive. An archive
  expires about seven days after it is created and can be downloaded five times,
  which bounds the retries of a failed download.

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
  the ownership. The `photos` role pins that UID, which the module leaves to
  NixOS to assign, and the database's state directory is owned in the same way
  by the guest's Postgres UID. This is the case the framework's privileged
  opt-in does not cover.
- **A container, not a VM.** A bind-mounted dataset keeps the library on the
  node's ZFS, where the node's backup job reads it; in a VM the library would
  sit in a virtual disk, out of that job's reach, on a filesystem stacked on
  ZFS. Upstream recommends a full VM for its Docker deployment and advises
  against Docker in LXC, which a native service does not use. Whether the
  module's hardened units start in an unprivileged container is checked first in
  the rollout, on a scratch container with the nesting feature that the
  framework enables. If a unit does not start, the hardening settings that fail
  are relaxed for that unit alone, and each one is recorded here as a deviation.
  A VM comes only if that is not enough, through a revision of this
  specification: the library's bind mount and the node's backup job would need
  another design there.
- **NixOS 26.11, with the fleet.** Immich 3 is in no stable NixOS release before
  26.11: 25.11 and 26.05 carry 2.7.5, which 26.05 marks as no longer updated. A
  second nixpkgs pin for this guest alone was rejected as a mechanism for a gap
  of weeks.

## Storage

| Data                                      | Where                                                         | Replaceable                                                                                  |
| :---------------------------------------- | :------------------------------------------------------------ | :------------------------------------------------------------------------------------------- |
| Originals, profile data, database dump    | `tank-hdd/photos`, bind-mounted as Immich's media location    | No                                                                                           |
| Thumbnails and transcoded videos          | The same dataset                                              | Yes: Immich regenerates them                                                                 |
| Postgres data directory                   | A state directory on pve2's root disk (NVMe), bind-mounted    | Yes: restored from the dump                                                                  |
| Machine learning model cache              | The container's root filesystem                               | Yes: downloaded again                                                                        |
| Takeout archives, files to import         | `tank-hdd/photos-import`, a `photos-import` share on nas-pve2 | Yes, once their checks have passed: the library and the records directory hold their content |
| Check records, kept files of the archives | The records directory of the same dataset                     | No                                                                                           |

- The database stays off the library's hard disk and off any network share, as
  the Immich requirements ask. The state directory follows the pattern of the
  NAS containers' state directories
  ([NAS LXC Container](./nas-lxc-container.md)), so it survives a container
  recreation.
- A database dump is written every day into the media location, at Immich's
  default of 02:00, so one dataset holds everything a restore needs: the
  originals and the metadata. A dump that was missed because pve2 was off is
  written after the next start.
- The storage template is enabled before the first import, with Immich's default
  layout (`Year/Year-Month-Day/Filename.Extension` under a directory per user),
  so the originals stay readable without Immich and its database.
- The staging dataset and its share follow the three coupled declarations of a
  [per-host share](./nas-lxc-container.md#51-adding-per-host-shares). The photo
  guest has no mount of it: the import tool and the check script run on the pve2
  node, as the user that owns the staging files, and reach the server through
  its API over the node's bridge. The archives therefore do not leave pve2, and
  the service that parses every upload never sees them. Each account's API key
  is given to the tools when they run and is not stored on the node.

Decision:

- **No staging mount in the guest.** In an unprivileged guest the owner of the
  staging files is an unmapped user, so the guest could read them only if every
  process on the node could, or through an access rule for the guest's mapped
  user on the dataset. The import tool is an API client and the check script
  reads the backup repository on the node, so neither has to run in the guest.

## Exports and imports

Each Google account is handled on its own, one after the other, because an
archive expires in about seven days:

1. Items in the Locked Folder that must be kept are moved out of it: Google's
   [transfer documentation](https://support.google.com/accounts/answer/9666875)
   excludes them, and the export is assumed to do the same.
2. The export is requested for Google Photos alone, with every album and every
   year, as ZIP parts of 50 GB, delivered as download links. Delivery to Google
   Drive is not an option: Drive shares the storage quota that is nearly full.
3. The parts are downloaded to the staging share, in a directory per account.
4. Checks 1 and 2 below run on the archives, and the sample of check 4 is
   compared with them. They need no server, so they can run before the guest
   exists.
5. The archives are imported into that person's Immich account with
   [immich-go](https://github.com/simulot/immich-go), the tool the
   [Immich documentation](https://docs.immich.app/features/command-line-interface)
   recommends for Takeout, in a release that supports the server's major version
   (0.32.0 for Immich 3), run on the pve2 node, first as a dry run. The import
   applies the sidecar files and recreates the albums that have a title, which
   is the tool's default. No option of the tool that drops a file (of a burst,
   of a RAW and JPEG pair) is used. It includes archived items and the media
   files that have no sidecar, and leaves out trashed items and items shared by
   a partner. Partner sharing is in use between the household's accounts (stated
   on 2026-11-27), so the partner's own export is expected to carry such an
   item, and check 3 confirms it for each one: an item that the partner's
   library account does not hold is imported into the receiving account.
6. Checks 3 to 5 run, and the results go into the account's record, in the
   records directory of the staging dataset.
7. What the library does not hold is extracted from the archives into the same
   directory: every file that is not a media file, among them the sidecar files,
   which hold what an import tool may not apply, and every media file whose
   content hash the library does not hold. The library backup job covers the
   records directory. After this step the archives are no copy of anything: they
   stay on the staging share while the space allows, and no backup holds them.

The files from the other machine are copied to the staging share and imported as
a folder into their owner's account; check 3 applies to them.

Decision:

- **Partner items are stored once.** Importing them into each account, which is
  the default of immich-go, needs no assumption about the other account, but
  stores every shared item twice.

## Export checks

No single check proves that an export is complete, at full resolution, with its
metadata. Each account passes these, in order. One script, written with the
rollout, runs checks 1 to 3 and 5 and writes the record; the
[deletion check](#deletion-check) runs the same code.

| Check                | Passes when                                                                                                                                                                                                                                                                                                                                                                                         | Does not prove                                     |
| :------------------- | :-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | :------------------------------------------------- |
| 1. Archive integrity | Every part the export page lists is present and every ZIP passes its integrity test                                                                                                                                                                                                                                                                                                                 | That Takeout put every item in the archive         |
| 2. Pairing           | Every sidecar file has its media file in the archive; the media files with no sidecar are listed                                                                                                                                                                                                                                                                                                    | Anything about an item missing with its sidecar    |
| 3. Import accounting | Every distinct media file of the archive, by its SHA-1 hash, is an asset of the account outside its trash, or is in the record with the reason it was left out; a partner's item counts as left out only once the partner's account holds its content hash, which waits for that account's import                                                                                                   | That the metadata arrived                          |
| 4. Byte identity     | A sample of about twenty files copied from each phone, photos and videos, has the content hashes of the archive's files; then the app's first backup uploads nothing captured before the export was requested, and each exception is recorded                                                                                                                                                       | Anything about items that are on no device anymore |
| 5. Metadata          | Every album folder of the archive has an album with its item count in the library, or is listed in the record as a warning, which is where an album without a title appears; the favorites have their count; a sample of items edited in Google Photos shows the edited date, location, and description, and holds a motion photo with its video part and an item whose metadata was edited by hand | That every item's metadata arrived                 |

Check 4 uses the app's deduplication: it computes a checksum of each local file
and skips the ones the server already holds
([mobile backup](https://docs.immich.app/features/mobile-backup)), so a skipped
file is byte-identical to the one Takeout delivered. Whether Takeout returns the
uploaded bytes of an original-quality item is not documented; this check
measures it.

The sample comes before any phone is enabled, because the documentation
describes no view of what the app is about to upload: without the sample, a
mismatch shows only once every earlier file of the phone was uploaded as a
second copy beside the one of Takeout. If the sample does not match, no phone is
enabled and this specification is revised first, since the matching of the
[deletion check](#deletion-check) depends on the same answer.

What no check of an export covers: an item that Takeout left out together with
its sidecar and that is on no phone. Only Google Photos still shows it, and the
count comparison of the deletion check is what notices it before it is deleted
there.

## Deletion check

A set of items is deleted from Google Photos only after this check. It runs the
code of the export checks on a small archive, in this order:

1. The items to delete are put in an album in Google Photos.
2. That album alone is exported with Takeout and downloaded to the staging
   share, and export checks 1 and 2 run on the archive.
3. The count of items that the album shows in Google Photos equals the count of
   items in the archive, so an item that the export left out is noticed.
4. Every item of the archive passes the three conditions below.
5. The items that passed are deleted in Google Photos by hand: no Google Photos
   API deletes an item that the calling application did not create. Nobody
   empties the trash afterwards, where a deleted item stays for 30 days
   ([delete photos](https://support.google.com/photos/answer/6128858)), which is
   the time to undo the deletion.

| Condition                  | Passes when                                                                                                                    |
| :------------------------- | :----------------------------------------------------------------------------------------------------------------------------- |
| The library holds the copy | An asset of the owner's account has the content hash of the archive's file and is not in the trash                             |
| The metadata is current    | The asset's capture time, location, description, and favorite status equal those of the item's sidecar file                    |
| A snapshot holds both      | The newest snapshot of the library backup job holds the asset's file, and its dump is more recent than the asset's last update |

An item that fails a condition stays in Google Photos until its cause is found,
and the result of every run goes into the records directory, with the files of
the set's archive that step 7 of [Exports and imports](#exports-and-imports)
keeps: after the deletion, its sidecar files are the last record of what Google
Photos held.

Limits:

- A file that a phone uploaded to both services has the same hash in the archive
  and in the library only if Takeout returns the uploaded bytes, which export
  check 4 measures. If it does not, such an item is matched by its filename,
  capture time, and dimensions, and the record says that its bytes were not
  compared.
- The export of one album does not say which other albums of Google Photos hold
  the item, so the check does not compare album membership.
- How Takeout delivers an item that was edited in Google Photos is unverified.
- The operations the check needs from Immich (the lookup of an asset by its
  SHA-1 hash, the asset record with its path, its last update, and its metadata)
  were read in the API specification of Immich's main branch, which is newer
  than version 3.

Decision:

- **A Takeout of the set, not the Picker API.** The
  [Picker API](https://developers.google.com/photos/picker/reference/rest/v1/mediaItems)
  returns the items that a person picks, at most 2000 per session, with the file
  name, the capture time, the dimensions, and the camera. It has no description,
  location, favorite status, size, or hash, and its downloads are those of the
  Library API ([Why Google Takeout](#why-google-takeout)). It could show that an
  item exists in the library, not that the copy and the metadata are current.
  The cost of the Takeout is that the set is downloaded before it is deleted.

## Phone backup

- Every person has an Immich account of their own, and the Immich app on their
  phone backs up the camera folder, plus the folders that person selects, over
  Wi-Fi. The selection includes at least every folder that the Google Photos app
  backs up on that phone: the two selections are compared when the phone is set
  up, and the result goes into the account's record.
- The app is enabled on a phone only after that person's import has passed
  checks 1 to 3 and the sample of check 4 has matched, because the rest of check
  4 is the app's first backup.
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
  deletion in Google Photos then loses it. The [deletion check](#deletion-check)
  finds both before a deletion, and nothing reports them earlier:
    - The Immich backup of a phone stalls, or pve2 is off, and the file leaves
      the phone before the Immich app uploads it: its owner frees the space of
      what Google Photos has backed up, or deletes the item in the Google Photos
      app, which deletes it from the phone as well.
    - An item reaches Google Photos without passing through a folder that the
      Immich app backs up: an upload from a browser, an item saved from a shared
      album or from a partner, or a folder that someone enables later in the
      Google Photos app alone.

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

The response to that failure is decided (2026-11-27). The guest's configuration
permits that one package, by its name and version, so the rest of the guest
keeps receiving its updates, and a todo item records the exception with the
NixOS release that ends it. Two events end the exception earlier, by moving the
guest's Immich package to a newer nixpkgs:

- Upstream releases the second major version after the server's: the app on the
  phones then stops working with the server, with no error on the server.
- A published vulnerability of the server can be reached from the home network
  or through an uploaded file.

Decision:

- **Permit and wait, not a newer nixpkgs from the start.** The module at the
  locked revision has a `package` option that takes Immich from another nixpkgs,
  but it would keep installing the database extensions of the stable release,
  and it has no logic that depends on the package's version, so a newer package
  can fail to start and is tested at every update. The move is also one-way,
  since Immich migrates its database forward: the guest stays on the newer
  nixpkgs until a stable release ships a version at least as new.

Immich does not support downgrades: after an upgrade that migrated the database,
a rollback of the guest's system also needs the dump taken before the upgrade.
The restore rehearsal of [Copies and backup](#copies-and-backup) therefore
precedes an upgrade to a new major version.

## Copies and backup

| Data                              | Copies                                                                                                                                         |
| :-------------------------------- | :--------------------------------------------------------------------------------------------------------------------------------------------- |
| Items exported from Google Photos | Google Photos, for what is not deleted there; the library; the backup repository; the offsite copy                                             |
| Files from the other machine      | The library; the backup repository; the offsite copy                                                                                           |
| What the phones capture afterward | The phone, until its owner frees the space; Google Photos, for what is not deleted there; the library; the backup repository; the offsite copy |

The backup is a `restic-backup-photos` job of the backup role on pve2. The
[Backups specification](./backups.md) defines the job (its repository, its
schedule, its retention, its guard, and its drill) and holds the verification
matrix. This design asks five things of it:

- It covers the whole media location except the two directories of generated
  content, `thumbs` and `encoded-video`. Immich's
  [backup documentation](https://docs.immich.app/administration/backup-and-restore)
  names the directories that matter: `library`, `upload`, and `profile` for the
  originals, `backups` for the dumps.
- It also covers the records directory of the staging dataset: the check records
  and what the archives hold that the library does not.
- Every snapshot holds a database dump newer than the one of the previous
  snapshot, so a snapshot never succeeds with metadata older than the last one.
  The order is the one Immich's backup documentation recommends, the database
  first and the files second: after a restore, the worst case is a file that the
  database does not know.
- Its repository is on another disk than the library.
- It keeps monthly snapshots for a year beside the daily ones: a deletion or a
  corruption that Immich propagates is noticed late, long after seven daily
  snapshots have turned over.

The job runs while pve2 is on, and a run that was missed runs at the next start.

A restore is rehearsed, because the job's monthly restore drill proves that
restic restores a file and not that Immich comes back with its metadata. The
newest snapshot's dump and a sample of originals are restored into a scratch
guest. The rehearsal passes when the scratch server starts, the asset and album
counts of each account equal those of the live server, and the sampled originals
open. It runs before the first deletion in Google Photos and before each upgrade
of Immich to a new major version. Immich keeps a marker file in each directory
of the media location and does not start without it
([system integrity](https://docs.immich.app/administration/system-integrity)),
so a restore recreates the two excluded directories with their markers.

The offsite copy is a copy of the job's repository at the offsite or cloud
destination of the [Backup](./README.md#backup) todo items, which name no
destination yet. It is made and verified like the second copy of the lab's other
restic repositories, which the same items describe.

Decisions:

- **restic, not ZFS replication.** Replication to another pool would copy the
  dataset with less work per run, but the repository checks, the pack reads, the
  restore drill, and their alerts exist for restic only, and irreplaceable data
  is where they matter most.
- **A rehearsal of the metadata, not of the whole library.** A full restore
  would also measure the restore time at the real size, for about 300 GB of
  scratch space and hours of reading from the repository's disk. The job's
  scheduled checks already read the packs that hold the originals.
- **A copy outside the home is part of this design.** Google Photos does not
  count as one, because items are deleted there. Until the offsite copy exists,
  every copy the lab holds is in one machine, pve2, and an item deleted from
  Google Photos has no copy elsewhere.

## Monitoring

- An HTTP probe of the monitoring backends on
  `http://photos-pve2.edge.lab.ferrari.how:2283/api/server/ping`, which answers
  without authentication. The probe uses the backends' existing HTTP module,
  which checks for a success status and not for the body; the rollout confirms
  the path on the deployed version. It tells that the server answers, and the
  next item covers the services behind it.
- The guest imports the `monitoring` role and joins the NixOS containers group
  of the Ansible inventory, from which the backends derive their scrape targets.
  The group turns the scrape off, because the NAS containers import no
  `monitoring` role, so the guest's host variables turn it on again with
  `enable_prometheus_node_exporter_scraping`. `SystemdUnitFailed` then covers
  the Immich server, the machine learning service, Postgres, and the cache.
- A dump that stopped being written fails the backup job at its next run, which
  `SystemdUnitFailed` reports on pve2, and `ResticBackupStale` follows.
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
