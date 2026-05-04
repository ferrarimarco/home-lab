{
  disko.devices = {
    disk = {
      main = {
        type = "disk";
        # TODO
        device = "/dev/vda";
        # 1. Create a GPT partition table.
        # 2. Reserve 512MB for the EFI boot partition
        # 3. Give the rest to the root filesystem
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              size = "512M";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = [ "umask=0077" ];
              };
            };
            root = {
              size = "100%";
              content = {
                type = "filesystem";
                format = "ext4";
                mountpoint = "/";
              };
            };
          };
        };
      };
    };
  };
}
