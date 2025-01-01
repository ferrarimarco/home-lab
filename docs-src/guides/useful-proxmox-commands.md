# Proxmox admin notes

- Check if there are cloud-init datasource updates: `qm cloudinit pending <VM_ID>`
- Update cloud-init datasource: `qm cloudinit update <VM_ID>`
- Get the next proxmox VM ID: `pvesh get /cluster/nextid`
- Get the list of PCI devices of a given Proxmox host: `pvesh get /nodes/{nodename}/hardware/pci --pci-class-blacklist ""`
- Delete the EFI disk: `qm set <VM_ID> -delete efidisk0`

## Disable Secure Boot

Either enter the UEFI console and disable Secure Boot manually, or delete the
EFI disk, and recreate it without the `pre-enrolled-keys=1` option.

Notes:

- Secure Boot prevents unsigned kernel modules from loading.
  Example: Coral PCIe modules (`apex`, `gasket`)

## Expand disk, filesystem, and partition

On the Proxmox host:

1. Resize the partition using the GUI (VM -> Hardware -> Select disk -> Disk
   action -> Resize disk). To get the max capacity, see the corresponding storage
   pool page in the Proxmox admin GUI.

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
