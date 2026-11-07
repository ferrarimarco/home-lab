{
  lib,
  stdenvNoCC,
  dosfstools,
  mtools,
  e2fsprogs,
  util-linux,
  xz,
}:

# A stand-in for a vendor disk image, for the netboot-server integration test:
# an MBR image with a FAT boot partition holding placeholder boot files and
# an ext4 root with the files the role touches, built without privileges
# (mtools for FAT, mkfs.ext4 -d for ext4) and compressed like the real one.
# The output also carries the image's SHA-256 for the test override to pin.
stdenvNoCC.mkDerivation {
  name = "mock-netboot-image";

  nativeBuildInputs = [
    dosfstools
    mtools
    e2fsprogs
    util-linux
    xz
  ];

  dontUnpack = true;

  buildPhase = ''
    mkdir boot root
    for file in start4.elf fixup4.dat bcm2711-rpi-4-b.dtb kernel8.img initramfs8; do
      echo "placeholder $file" > "boot/$file"
    done
    echo "arm_64bit=1" > boot/config.txt
    echo "console=serial0,115200 root=PARTUUID=00000000-02 rootfstype=ext4" > boot/cmdline.txt
    echo "#cloud-config" > boot/user-data
    echo "instance_id: vendor" > boot/meta-data
    echo "network: {version: 2}" > boot/network-config
    mkdir boot/overlays
    echo "placeholder overlay" > boot/overlays/README

    # The mount point of the boot partition and the unit directory the
    # prepare step writes into, empty as in the image.
    mkdir -p root/etc/systemd/system root/boot/firmware root/usr/local/sbin
    echo "raspberrypi" > root/etc/hostname
    printf '%s\n' \
      'proc            /proc           proc    defaults          0       0' \
      'PARTUUID=00000000-01  /boot/firmware  vfat    defaults          0       2' \
      'PARTUUID=00000000-02  /               ext4    defaults,noatime  0       1' \
      > root/etc/fstab

    # Partitions: 8 MiB of FAT from sector 2048, 32 MiB of ext4 after it.
    truncate -s 8M boot.img
    mkfs.vfat boot.img > /dev/null
    mcopy -i boot.img -s boot/* ::/
    truncate -s 32M root.img
    mkfs.ext4 -q -F -d root root.img

    truncate -s 44M disk.img
    sfdisk --quiet disk.img <<'LAYOUT'
    label: dos
    start=2048, size=16384, type=c
    start=18432, size=65536, type=83
    LAYOUT
    dd if=boot.img of=disk.img bs=512 seek=2048 conv=notrunc status=none
    dd if=root.img of=disk.img bs=512 seek=18432 conv=notrunc status=none
    xz --threads=1 --stdout disk.img > mock.img.xz
  '';

  installPhase = ''
    mkdir "$out"
    cp mock.img.xz "$out/"
    sha256sum mock.img.xz | cut -d ' ' -f 1 | tr -d '\n' > "$out/sha256"
  '';

  meta.description = "Mock disk image for the netboot-server integration test";
  meta.license = lib.licenses.mit;
}
