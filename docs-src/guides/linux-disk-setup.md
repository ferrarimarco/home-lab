# Setup disks, partitions, and filesystems on Linux

- Get the list of block devices: `lsblk`
- Get the attributes of a block device: `blkid <device>`
- Get the list of disks and partitions and add the partition UUID: `lsblk -o NAME,FSTYPE,SIZE,MOUNTPOINT,PARTUUID`
