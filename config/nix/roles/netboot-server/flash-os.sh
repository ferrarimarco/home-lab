#!/usr/bin/env bash
# Write a pinned Raspberry Pi OS image to a whole disk from the network-boot
# rescue system, then install the cloud-init files of the installed system
# and the SSH switch file on its boot partition. Delivered to the rescue
# system by the netboot-server role through its cloud-init seed. Never
# reboots, never touches the EEPROM.
set -o errexit
set -o nounset
set -o pipefail

usage() {
  cat <<USAGE
Usage: flash-os --image URL --sha256 HEX --disk /dev/disk/by-id/ID --seed URL

  --image   URL of the compressed (.img.xz) image on the boot server
  --sha256  expected SHA-256 of the compressed image
  --disk    the whole target disk, by its stable device ID
  --seed    URL prefix of the installed system's cloud-init files
            (user-data, meta-data, network-config)
USAGE
}

image=""
sha256=""
disk=""
seed=""
while [[ $# -gt 0 ]]; do
  if [[ $# -lt 2 ]]; then
    usage >&2
    exit 1
  fi
  case "$1" in
  --image) image="$2" ;;
  --sha256) sha256="$2" ;;
  --disk) disk="$2" ;;
  --seed) seed="$2" ;;
  *)
    usage >&2
    exit 1
    ;;
  esac
  shift 2
done
if [[ -z $image || -z $sha256 || -z $disk || -z $seed ]]; then
  usage >&2
  exit 1
fi
if [[ $(id -u) -ne 0 ]]; then
  echo "flash-os must run as root" >&2
  exit 1
fi

if [[ $disk != /dev/disk/by-id/* ]]; then
  echo "the target must be named by its stable device ID under /dev/disk/by-id" >&2
  exit 1
fi
device="$(readlink -f "$disk")"
if [[ $(lsblk --nodeps --noheadings --output TYPE "$device") != disk ]]; then
  echo "$disk resolves to $device, which is not a whole disk" >&2
  exit 1
fi
if [[ -n $(lsblk --noheadings --output MOUNTPOINTS "$device" | tr -d '[:space:]') ]]; then
  echo "$device has a mounted filesystem; unmount everything on it first" >&2
  exit 1
fi

echo "Target disk:"
lsblk --nodeps --output NAME,MODEL,SERIAL,SIZE "$device"
echo "Image: $image"
read -r -p "Type FLASH to overwrite $device: " token
if [[ $token != FLASH ]]; then
  echo "aborted" >&2
  exit 1
fi

work="$(mktemp -d /var/tmp/flash-os.XXXXXX)"
cleanup() {
  umount "$work/boot" 2>/dev/null || true
  rm -rf "$work"
}
trap cleanup EXIT

echo "Downloading the image"
curl --fail --location --progress-bar --output "$work/image.img.xz" "$image"
echo "$sha256  $work/image.img.xz" | sha256sum --check
echo "Writing $device"
xz --decompress --stdout "$work/image.img.xz" | dd of="$device" bs=4M conv=fsync status=progress
sync
blockdev --rereadpt "$device"
udevadm settle

boot_partition="$(lsblk --noheadings --raw --output PATH "$device" | sed -n 2p)"
if [[ -z $boot_partition ]]; then
  echo "no boot partition found on $device after the write" >&2
  exit 1
fi
mkdir "$work/boot"
mount "$boot_partition" "$work/boot"
for file in user-data meta-data network-config; do
  curl --fail --location --silent --show-error --output "$work/boot/$file" "$seed/$file"
done
# The image leaves sshd disabled; its boot-time switch enables it when this
# file exists, then removes the file. The seed cannot do it: cloud-init only
# restarts a running sshd when it applies the password setting.
touch "$work/boot/ssh"
umount "$work/boot"

echo "Done: $device carries the image and the cloud-init files from $seed."
echo "Stop the host's toggle on the boot server, then reboot."
