# Proxmox admin notes

- Check if there are cloud-init datasource updates: `qm cloudinit pending <VM_ID>`
- Update cloud-init datasource: `qm cloudinit update <VM_ID>`
- Get the next proxmox VM id: `pvesh get /cluster/nextid`
- Get the list of PCI devices of a given Proxmox host: `pvesh get /nodes/{nodename}/hardware/pci --pci-class-blacklist ""`
- Delete the EFI disk: `qm set <VM_ID> -delete efidisk0`

## Disable Secure Boot

Either enter the UEFI console and disable Secure Boot manually, or delete the
EFI disk, and recreate it without the `pre-enrolled-keys=1` option.

Notes:

- Secure Boot prevents unsigned kernel modules from loading.
    Example: Coral PCIe modules (`apex`, `gasket`)

## Expand disk, filesystem, and partition

See: <https://pve.proxmox.com/wiki/Resize_disks>.
