# Setup Proxmox

TODO: automate this if it becomes more common

## Download container templates

## Notes to create the 100 VM

1. Create VM: qm create 100 --name hl01 --net0
   virtio=BC:24:11:D4:F6:64,bridge=vmbr0,firewall=1 --scsihw virtio-scsi-single
   --machine q35 --ostype l26
1. Configure CPU and memory: qm set 100 --cpu host --cores 2 --memory 8192
1. Configure the VM to start at boot: qm set 100 --onboot 1
1. Enable QEMU guest agent: qm set 100 --agent enabled=1
1. Import raw disk: qm disk import 100
   /var/lib/vz/template/raw/debian-12-generic-amd64-20240211-1654.raw local-zfs
1. Attach and configure disk to the vm: qm set 100 -scsi0
   local-zfs:vm-100-disk-0,discard=on,iothread=1,size=2G,ssd=1,aio=io_uring
1. Resize: qm disk resize 100 scsi0 8G
1. Set boot order: qm set 100 --boot order=scsi0
1. Attach and configure a second disk from the rpool-sata pool: qm set 100
   -scsi1
   rpool-sata:vm-100-disk-0,discard=on,iothread=1,size=113G,ssd=1,aio=io_uring
1. Attach and configure a third disk from the rpool-usb-1 pool: qm set 100
   -scsi1
   rpool-usb-1:vm-100-disk-1,discard=on,iothread=1,size=885G,ssd=1,aio=io_uring
1. Enable UEFI and create a UEFI disk volume: qm set 100 --bios ovmf
1. Configure UEFI disk volume: `qm set 100 --efidisk0 local-zfs:0,efitype=4m`.
   If you need Secure Boot, add the "pre-enrolled-keys=1" option
1. Configure cloud-init datasource: qm set 100 --cicustom
   "user=local:snippets/cloud-init-hl01-user-data.yaml,network=local:snippets/cloud-init-hl01-network.yaml"
1. Configure cloud-init drive: qm set 100 --ide2 local-zfs:cloudinit,media=cdrom
1. Pass the Coral PCIe module to the VM, mark it as a PCIe device: qm set 100
   --hostpci0 0000:03:00,pcie=1
1. Pass the iGPU to the VM, mark it as a PCIe device, make the firmware ROM
   visible to the guest, set it as the primary GPU: qm set 100 -hostpci1
   0000:00:02.0,pcie=on,rombar=on,x-vga=on
1. Start the VM: qm start 100
