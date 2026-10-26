# Linux administration notes

## Reach the hosts

Connect over SSH using each host's fully qualified domain name as the Ansible
inventory lists it (`<host>.edge.lab.ferrari.how`): the short hostnames do not
resolve from the control machine. Log in as `root` on the Proxmox nodes, as
`debian` on the hl01 VM, as `pi` on raspberrypi2, and as the administrative user
of the `common` Nix role on the NixOS hosts.

A first connection to a host from a machine fails under `BatchMode=yes` with
"Host key verification failed", the line a changed key's output also ends with.
Tell the two apart before accepting anything: `ssh-keygen -F <fqdn>` (the name
as SSH stored it; `-f` selects a known hosts file other than
`~/.ssh/known_hosts`) prints nothing for a host that file never saw, and an
entry for a mismatch. For an unknown host, connect once with
`-o StrictHostKeyChecking=accept-new`; for a mismatch, find out why the key
changed before touching the known hosts file.

## Debian

### OS package management

- Get the versions that are available to install of a package:
  `apt-cache madison <package-name>`
- Install a specific package version:
  `apt-get install <package-name>=<package-version-number>`
- The package update logs are in `/var/log/apt/history.log`

## Networking

- Get the list of open ports on a system (with superuser privileges, it also
  returns process information): `sudo netstat -nlp`

## Restic

The [backup operations guide](./operations/backup.md) has the inspection,
restore, drill, and repair procedures.

- Open a shell in the Restic container:

    ```sh
    sudo docker compose --file /etc/ferrarimarco-home-lab/restic/compose.yaml run --build --interactive --rm --entrypoint /bin/bash restic-backup-workloads
    ```

## Disks, partitions, and filesystems

- Get the list of block devices: `lsblk`
- Get the attributes of a block device: `blkid <device>`
- Get the list of disks and partitions and add the partition UUID:
  `lsblk -o NAME,FSTYPE,SIZE,MOUNTPOINT,PARTUUID`
