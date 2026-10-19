# Network share clients

This guide covers the hosts that mount the NAS container's SMB shares over CIFS
(hl01 and raspberrypi2) and run containers that bind directories inside them.
The design behind the mounts, the boot ordering, and the mount-point guard is in
the [NAS LXC container page](../../architecture/nas-lxc-container.md) (SMB
clients section); this page holds the checks and the recovery recipes.

## How a share reaches a container

Docker resolves a bind mount's host path when it creates or starts a container,
and keeps that mount for the container's lifetime. A container that starts while
the share is absent binds the bare mount-point directory on the host's own disk,
and keeps it after the share mounts: the share's arrival does not propagate into
a bind of a subpath. The two mechanisms the NAS page describes prevent that at
boot (the mount attempt is ordered before Docker) and make it fail loudly
otherwise (the bare directory is immutable, so Docker cannot create the bind
source and the container does not start).

## Check what a container sees

Compare the container's view with the host's. On hl01, for Jellyfin:

```shell
docker exec jellyfin ls /media/Series | wc -l
ls /media/data0/media/media/Series | wc -l
```

Matching counts mean the container holds the share. A container that lists
nothing, or whose logs say `Could not find file` for every item while the file
exists on the host, is bound to the bare directory (or to a directory that no
longer exists, after the guard). The filesystem behind the bind settles it:

```shell
docker exec jellyfin cat /proc/self/mountinfo | grep ' /media '
```

A `cifs` line names the share; an `ext4` line names the host's root disk.

Check the host side first when both views are empty:

```shell
findmnt /media/data0 -o SOURCE,FSTYPE
systemctl status media-data0.mount
```

## Recover a container that holds the bare directory

Once the share is mounted on the host, restart the Compose project; Docker
resolves the bind sources again on every start, so a recreate is not needed
(verified on hl01 on 2026-10-19):

```shell
docker compose -f /etc/ferrarimarco-home-lab/media-stack/compose.yaml restart
```

Then repeat the check above. Jellyfin keeps its library in its database, so the
items reappear as playable without a rescan.

## Recover after a boot with the NAS unreachable

When the NAS container is down while a client boots, the mount attempt fails,
`ExpectedMountMissing` fires for the mount point, and the containers that bind
the share stay stopped: Docker refuses to create a bind source under the
immutable mount point, and a restart policy only retries a container that
exited, not one that failed to start. Docker's `compose up` brings up the
services of the project that do not bind the share and leaves the others in the
`Created` state. Nothing retries on its own (automatic recovery is a todo item
of the [architecture index](../../architecture/README.md)).

Once the NAS is back:

1. Mount the share (the unit name is the escaped mount path; `systemctl` also
   accepts the path itself):

    ```shell
    sudo systemctl start /media/data0 /media/backup-0
    findmnt -t cifs -o TARGET,SOURCE,FSTYPE
    ```

2. Bring the projects up. `up -d` starts the stopped services and leaves the
   running ones alone:

    ```shell
    docker compose -f /etc/ferrarimarco-home-lab/media-stack/compose.yaml up -d
    docker compose -f /etc/ferrarimarco-home-lab/restic/compose.yaml up -d
    ```

    The restic backup job needs no action: its timer unit requires the mount and
    runs at its next schedule.

3. Repeat the container check above and confirm the alert resolved.

A NAS restart while the clients are up needs none of this: the kernel's CIFS
client keeps the mount and reconnects when the server returns (both shares
stayed mounted on hl01 through the NAS container reboots of 2026-10-03 and
2026-10-09, with no alert). I/O in flight gets an error and the applications
retry on their own.

## Inspect the bare mount point

The guard refuses to run while the bare directory holds entries, and names them.
To look at the directory while the share is mounted, bind its parent in a
private mount namespace, which hides the share and leaves nothing mounted
behind:

```shell
sudo unshare --mount --propagation private sh -c \
  'mount --bind /media /mnt && lsattr -d /mnt/data0 && ls -la /mnt/data0'
```

The `i` in the attribute column is the immutable flag. Remove leftover entries
by hand from the same namespace (an empty directory tree from a playbook run or
a container start that happened while the share was absent is the usual finding;
check for files before removing anything), then run the setup-disks playbook
again. While the share is absent, an ownership or mode change of the mount point
also fails on the immutable directory, so clear the flag first for that too.
Clearing the flag by hand, for example before removing the mount point, is
`chattr -i` on the same path inside the namespace; the role clears it when the
entry sets `protect_mount_point: false`.
