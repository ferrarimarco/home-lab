# Storage configuration

## Storage planning

## ZFS topology

ZFS pool of mirrored vdevs.

## Storage access

For containers: bind mount ZFS datasets to LXC containers that need them.

For VMs: bind mount ZFS datasets to a LXC container running NFS and Samba
servers, then mount shares in VMs that need them.
