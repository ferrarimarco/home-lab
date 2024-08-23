# Expand a partition and a filesystem on Debian

1. Backup the current partition table:

   ```sh
   sfdisk -d /dev/sda > sda_partition_bakup.dmp
   ```

1. Get details about the changes to the partition table to apply (dry-run) to
   see what will be changed:

   ```sh
   growpart -N /dev/sda 1
   ```

1. Apply changes to the partition table:

   ```sh
   growpart /dev/sda 1
   ```

1. Resize the file system:

   ```sh
   resize2fs /dev/sdb1
   ```

1. Check the file system size:

   ```sh
   df -h
   ```
