# Useful Proxmox commands

- Check if there are cloud-init datasource updates: `qm cloudinit pending <VM_ID>`
- Update cloud-init datasource: `qm cloudinit update <VM_ID>`
- Get the next proxmox VM id: `pvesh get /cluster/nextid`
- Get the list of PCI devices of a given Proxmox host: `pvesh get /nodes/{nodename}/hardware/pci --pci-class-blacklist ""`
