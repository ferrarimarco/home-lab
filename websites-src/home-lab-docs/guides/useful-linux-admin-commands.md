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

### Release upgrade

The playbooks upgrade a Debian host in place to the next release; the host keeps
its state trees and its container images, and the upgrade costs one reboot. A
fresh install (a VM rebuilt from a cloud image, a re-imaged Raspberry Pi)
follows the fresh host procedure of the
[backup operations guide](./operations/backup.md) instead.

1. Read the host: `apt-mark showhold` (nothing held), the packages installed
   from backports or third-party repositories (`apt list --installed`, the
   release notes of the new release say which are known to break), and the free
   space on the root filesystem (the upgrade needs a few gigabytes).
2. Secure the pre-change copy: run the host's backup job by hand and confirm its
   snapshot, and for a VM snapshot its root volume on the node
   (`zfs snapshot rpool/data/vm-<id>-disk-<n>@pre-<release>`), the rollback for
   a broken upgrade (`zfs rollback` with the VM stopped). Silence the host's
   alerts as the [monitoring operations guide](./operations/monitoring.md)
   describes.
3. Point APT at the new release through the bootstrap playbook, which renders
   the Debian sources from `debian_release_force_upgrade` instead of the running
   release, check run first:

    ```shell
    ADDITIONAL_ANSIBLE_FLAGS="--check --diff --limit <host> -e debian_release_force_upgrade=<codename>" \
      ANSIBLE_PLAYBOOK_FILE_NAME="bootstrap.yaml" scripts/run-ansible.sh
    ```

    Third-party sources (Docker's) keep the old release name until their role
    runs on the upgraded host; their packages for the old release install on the
    new one in the meantime.

4. Predict the upgrade on the host (`sudo apt full-upgrade --simulate`), and
   review the removals: a package the new release drops takes its dependents
   with it. Then run the OS packages playbook limited to the host; its
   dist-upgrade task runs detached from the SSH session, so a dropped connection
   does not interrupt it, and the playbook keeps the existing configuration
   files where the new packages ship changed defaults (the new files land beside
   them with a `.dpkg-dist` suffix).
5. Reboot, then verify: the release in `/etc/os-release`, the running kernel,
   the boot time, the services from a fresh listing, the mounts, and the
   out-of-tree kernel modules (`dkms status`), whose DKMS builds run during the
   kernel install and fail there, not at boot: a failed build fails the kernel
   package's post-install hook, apt stops with the kernel and headers
   unconfigured, and the host keeps booting the old kernel. Fix the module
   source (on hl01 on 2026-11-04, the Coral driver source predated the pinned
   package and lacked the fixes for kernel 6.12: `dpkg -i` of the pinned file
   replaced it), then `dpkg --configure -a` configures the pending packages and
   runs the hook again. The package run itself took four minutes on hl01 for 424
   upgraded and 129 new packages.
6. Converge on the new release: the container engine playbook moves the Docker
   source to the new release, and the node playbook surfaces whatever the
   release changed under the roles, check runs first.

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
