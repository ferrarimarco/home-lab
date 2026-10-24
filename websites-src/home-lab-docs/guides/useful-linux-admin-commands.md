# Linux administration notes

## Reach the hosts

Connect over SSH using each host's fully qualified domain name as the Ansible
inventory lists it (`<host>.edge.lab.ferrari.how`): the short hostnames do not
resolve from the control machine. Log in as `root` on the Proxmox nodes, as
`debian` on the hl01 VM, and as `pi` on raspberrypi2.

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
