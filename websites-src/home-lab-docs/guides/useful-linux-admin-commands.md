# Linux administration notes

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

- Open a shell in the Restic container:

    ```sh
    sudo docker compose --file /etc/ferrarimarco-home-lab/restic/compose.yaml run --build --interactive --rm --entrypoint /bin/bash restic-backup-workloads
    ```

## Disks, partitions, and filesystems

- Get the list of block devices: `lsblk`
- Get the attributes of a block device: `blkid <device>`
- Get the list of disks and partitions and add the partition UUID:
  `lsblk -o NAME,FSTYPE,SIZE,MOUNTPOINT,PARTUUID`
