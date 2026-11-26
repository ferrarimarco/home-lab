# Proxmox administration notes

- Check if there are cloud-init datasource updates:
  `qm cloudinit pending <VM_ID>`
- Update cloud-init datasource: `qm cloudinit update <VM_ID>`
- Get the next proxmox VM ID: `pvesh get /cluster/nextid`
- Get the list of PCI devices of a given Proxmox host:
  `pvesh get /nodes/{nodename}/hardware/pci --pci-class-blacklist ""`
- Delete the EFI disk: `qm set <VM_ID> -delete efidisk0`

## Run commands in NixOS containers

`pct exec` does not source a login shell, and a NixOS container keeps its
binaries under `/run/current-system/sw/bin`, which is not on the default `PATH`
of the spawned process: a plain `pct exec <vmid> -- <cmd>` fails with "No such
file or directory". Call the binary by its full path, or wrap the command in a
login shell so the NixOS profile sets `PATH`:

```shell
pct exec <vmid> -- /run/current-system/sw/bin/<cmd>
pct exec <vmid> -- /bin/sh -lc '<cmd> <args>'
```

## Diagnose a container that failed its boot-time start

`pve-guests` logs only `startup for container '<id>' failed`. Read the start
task's log under `/var/log/pve/tasks/` (the `vzstart:<id>` UPID) and
`/run/pve/ct-<id>.stderr`, where the pre-start hook names what it refused (a
bind-mount source that did not exist, in the case of 2026-11-10). For a missing
ZFS dataset, compare the container's start time with the pool's import time
(`zpool history <pool>`): a pool that only Proxmox's storage activation imports
can arrive after the guests start, while one with a `zfs-import@` instance is
imported before them, as the
[NAS LXC container specification](../../architecture/nas-lxc-container.md)
describes under the host dataset mount points. `pct start <id>` recovers the
guest.

## A changed cloud-init snippet provisions the VM again

Proxmox gives a VM with custom cloud-init snippets an instance identifier that
is the SHA-1 of its user data followed by its network data (read in
`PVE/QemuServer/Cloudinit.pm` of qemu-server 9.2.24), and writes it to the
cloud-init drive at every start. cloud-init treats a new identifier as a new
machine and runs its per-instance modules again: it regenerates the SSH host
keys, rewrites the authorized keys and `/etc/hosts`, and runs the package
modules of the user data.

The Proxmox role therefore treats the snippets as seeds: it renders one only
when the file is absent, and reports, in check mode too, a snippet that differs
from what it would render now. A change to the templates or to the inventory
reaches a VM in two cases, both started by deleting its snippet on the node and
running the Proxmox playbook:

- Before the VM is rebuilt, so that the new VM is not provisioned with old data
  (an authorized key that was rotated since).
- To provision a running VM again at its next start, on purpose. The user data
  sets `ssh_deletekeys: false`, so that such a VM keeps its SSH host keys;
  whether the Debian cloud image carries host keys of its own, which that
  setting would then keep on a new VM, was not checked: compare the dates of
  `/etc/ssh/ssh_host_*` with the first boot on a rebuilt VM.

Disabling cloud-init on a provisioned VM (`/etc/cloud/cloud-init.disabled`) was
the alternative: it also ends the growth of the root filesystem at boot after a
disk resize. A fixed identifier through a metadata snippet was the other: the
Terraform provider replaces the VM when that file is set (`ForceNew`, read in
its source at 0.111.1).

hl01 went through this on 2026-11-26, at the first start since its user data
changed on 2026-11-10 (the list of authorized keys), when the role still rewrote
the snippets. To read the state of a VM:

- The identifier the next start will use, on the node, against the one the guest
  holds: `cat <user data snippet> <network data snippet> | sha1sum` and
  `/var/lib/cloud/data/instance-id` in the guest. Equal values mean no new
  instance. `qm cloudinit dump <id> meta` does not answer this: it hashes the
  user data Proxmox would generate and ignores the snippets.
- What changed between two instances: cloud-init keeps the user data of each
  under `/var/lib/cloud/instances/<identifier>/user-data.txt`.
- Whether a host that presents new SSH host keys is still the same VM: read the
  key files through the guest agent
  (`qm guest exec <id> -- ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub`) and
  compare the fingerprint with the one the address offers.

The host keys come back from the host's backup with the SSH identity restore of
the [backup operations guide](./backup.md), from a snapshot older than the
start; the units that cloud-init left failed are cleared with
`systemctl reset-failed`. Both were done on hl01 that day (the host keys from
the snapshot of 01:00 UTC, the units `cloud-config.service` and
`cloud-init-main.service`).

## Old kernel series stay installed

A node keeps every kernel series it ever installed, and `apt autoremove` never
offers one for removal (pve1 held the 6.5, 6.8, 6.17, and 7.0 series on
2026-11-26, with pve-manager 9.3.1 and apt 3.0.4). Within a series the removal
works: the hook `/etc/kernel/postinst.d/proxmox-auto-removal` writes the kernels
to keep to `/etc/apt/apt.conf.d/76pveconf` as `APT::NeverAutoRemove` patterns
(the running kernel, the two newest, the two newest series with the newest
kernel of the older one, and the pinned or manually added ones), and autoremove
takes the other kernels of a series once its meta-package depends on a newer
one. That file only protects: nothing removes what it does not name.

Across series, each meta-package (`proxmox-kernel-<series>`) provides
`wireguard-modules`, which `wireguard-tools` recommends, and
`libpve-network-perl` recommends `wireguard-tools`, so it is installed on a
standard node. apt keeps every installed provider of a recommended virtual
package, so every series stays, with the newest kernel its meta-package depends
on. The simulation shows the reason for each package:

```shell
apt-get --simulate autoremove -o Debug::pkgAutoRemove=true 2>&1 | grep proxmox-kernel
```

A series that stays keeps receiving kernel updates, and each one sets the
reboot-required flag, since the hook `zzz-proxmox-reboot-required` sets it for
any installed kernel other than the running one. To remove a series that
`76pveconf` does not name, purge its meta-package and its kernels by name, and
read the simulation first: it must list those packages only.

```shell
apt-get --simulate --no-auto-remove purge proxmox-kernel-<series> proxmox-kernel-<version>-pve-signed
```

No report of this to Proxmox was found on 2026-11-26.

## Disable Secure Boot

Either enter the UEFI console and disable Secure Boot manually, or delete the
EFI disk, and recreate it without the `pre-enrolled-keys=1` option.

Notes:

- Secure Boot prevents unsigned kernel modules from loading. Example: Coral PCIe
  modules (`apex`, `gasket`)

## Expand disk, filesystem, and partition

On the Proxmox host:

1. Resize the partition using the GUI (VM -> Hardware -> Select disk -> Disk
   action -> Resize disk). To get the max capacity, see the corresponding
   storage pool page in the Proxmox admin GUI.

On the VM:

1. Get the device ID: `sudo dmesg | grep capacity`

1. Resize the partition:

    ```shell
    sudo parted /dev/<DEVICE_ID>

    # Get the partition ID
    print

    # Resize the partition
    resizepart <PARTITION_ID> 100%

    quit
    ```

1. Grow the filesystem:

    ```shell
    sudo resize2fs /dev/<DEVICE_ID><PARTITION_ID>
    ```

For more information, see <https://pve.proxmox.com/wiki/Resize_disks>.

## Capture network traffic of a Proxmox VM

In order to capture the network traffic that goes through a network interface of
a Proxmox VM, do the following:

1. Get the Proxmox VM ID.
1. Get the Proxmox VM interface name.
1. On the Proxmox node that hosts the VM, check that there's a `tap` network
   interface named `tap<VM_ID>i<NET_INTERFACE_ID>`.
1. On the Proxmox node that hosts the VM, run `tcpdump` in order to capture
   network traffic to a file:

    ```sh
    tcpdump -i tap<VM_ID>i<NET_INTERFACE_ID> -n -w <filename>.pcap
    ```

Source: <https://www.apalrd.net/posts/2023/tip_pcap/>
