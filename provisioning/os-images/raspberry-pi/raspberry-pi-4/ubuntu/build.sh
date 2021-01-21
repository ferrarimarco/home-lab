#!/usr/bin/env sh

set -o nounset
set -o errexit

echo "This script has been invoked with: $0 $*"

OS_VERSION="20.04.1"
IMAGE_ARCHIVE_FILE_NAME="ubuntu-${OS_VERSION}-preinstalled-server-arm64+raspi.img.xz"
IMAGE_URL="https://cdimage.ubuntu.com/releases/${OS_VERSION}/release/${IMAGE_ARCHIVE_FILE_NAME}"
IMAGE_CHECKSUM_FILE_NAME="SHA256SUMS"
IMAGE_CHECKSUM_URL="https://cdimage.ubuntu.com/releases/${OS_VERSION}/release/${IMAGE_CHECKSUM_FILE_NAME}"

WORKSPACE_DIRECTORY="$(pwd)"
echo "Working directory: ${WORKSPACE_DIRECTORY}"

IMAGE_ARCHIVE_FILE_PATH="${WORKSPACE_DIRECTORY}"/"${IMAGE_ARCHIVE_FILE_NAME}"

echo "Downloading the OS image from ${IMAGE_URL}..."
[ ! -f "${IMAGE_ARCHIVE_FILE_PATH}" ] && wget "${IMAGE_URL}"
[ ! -f "${IMAGE_CHECKSUM_FILE_NAME}" ] && wget -O "${IMAGE_CHECKSUM_FILE_NAME}" "${IMAGE_CHECKSUM_URL}"

echo "Verifying the integrity of ${IMAGE_ARCHIVE_FILE_PATH}..."
sha256sum --ignore-missing -c "${IMAGE_CHECKSUM_FILE_NAME}"

IMAGE_FILE_NAME="$(basename "${IMAGE_ARCHIVE_FILE_PATH}" .xz)"
IMAGE_FILE_PATH="${WORKSPACE_DIRECTORY}/${IMAGE_FILE_NAME}"

echo "Getting information about the ${IMAGE_ARCHIVE_FILE_PATH} archive: $(
  echo
  xz -l "${IMAGE_ARCHIVE_FILE_PATH}"
)"

if [ ! -f "${IMAGE_FILE_PATH}" ]; then
  echo "Extracting contents of ${IMAGE_ARCHIVE_FILE_PATH}..."
  unxz "${IMAGE_ARCHIVE_FILE_PATH}"
else
  echo "${IMAGE_FILE_PATH} already exists, skipping extraction..."
fi

echo "Gathering information about ${IMAGE_ARCHIVE_FILE_PATH}"
fdisk -l "${IMAGE_FILE_PATH}"

echo "Currently used loop devices:"
losetup --all

LOOP_DEVICE_PATH="$(losetup -f)"
echo "First available loop device: ${LOOP_DEVICE_PATH}"

echo "Mounting loop devices from ${IMAGE_FILE_PATH}..."
kpartx -asv "${IMAGE_FILE_PATH}"

mkdir -p /mnt/raspi-1
mkdir -p /mnt/raspi-2

LOOP_DEVICE_NAME="$(basename "${LOOP_DEVICE_PATH}")"
LOOP_DEVICE_PARTITION_PREFIX=/dev/mapper/"${LOOP_DEVICE_NAME}"
ROOTFS_DIRECTORY_PATH="/mnt/raspi-2"
echo "Mounting partitions from ${LOOP_DEVICE_PATH} (prefix: ${LOOP_DEVICE_PARTITION_PREFIX})"
mount -v "${LOOP_DEVICE_PARTITION_PREFIX}"p1 /mnt/raspi-1
mount -v "${LOOP_DEVICE_PARTITION_PREFIX}"p2 "${ROOTFS_DIRECTORY_PATH}"

echo "Current disk space usage:"
df -h

for d in /mnt/raspi-*/; do
  echo "$d contents:"
  ls -ahl "$d"
done

echo "Mounting /sys..."
if [ "$(mount | grep "${ROOTFS_DIRECTORY_PATH}"/sys | awk '{print $3}')" != "${ROOTFS_DIRECTORY_PATH}/sys" ]; then
  mount -t sysfs sysfs "${ROOTFS_DIRECTORY_PATH}/sys"
fi

echo "Mounting /proc..."
if [ "$(mount | grep "${ROOTFS_DIRECTORY_PATH}"/proc | awk '{print $3}')" != "${ROOTFS_DIRECTORY_PATH}/proc" ]; then
  mount -t proc proc "${ROOTFS_DIRECTORY_PATH}/proc"
fi

echo "Creating /dev/pts mount point..."
if [ ! -d "${ROOTFS_DIRECTORY_PATH}/dev/pts" ]; then
  mkdir -p "${ROOTFS_DIRECTORY_PATH}"/dev/pts || true
fi

echo "Mounting /dev/pts..."
if [ "$(mount | grep "${ROOTFS_DIRECTORY_PATH}"/dev/pts | awk '{print $3}')" != "${ROOTFS_DIRECTORY_PATH}/dev/pts" ]; then
  mount -t devpts devpts "${ROOTFS_DIRECTORY_PATH}/dev/pts"
fi

echo "Customizing ${ROOTFS_DIRECTORY_PATH} via chroot..."

CHROOT_RESOLV_CONF_PATH="${ROOTFS_DIRECTORY_PATH}"/run/systemd/resolve/stub-resolv.conf
CHROOT_RESOLV_CONF_DIRECTORY_PATH="$(dirname "${CHROOT_RESOLV_CONF_PATH}")"
CUSTOMIZED_RESOLV_CONF="false"
if [ ! -f "${CHROOT_RESOLV_CONF_PATH}" ]; then
  mkdir -p "${CHROOT_RESOLV_CONF_DIRECTORY_PATH}"
  printf "nameserver 8.8.8.8\n" >"${CHROOT_RESOLV_CONF_PATH}"
  CUSTOMIZED_RESOLV_CONF="true"
fi

echo "Contents of ${CHROOT_RESOLV_CONF_PATH}:"
cat "${CHROOT_RESOLV_CONF_PATH}"

echo "Pinging an external domain..."
chroot "${ROOTFS_DIRECTORY_PATH}" ping -c 3 google.com

chroot "${ROOTFS_DIRECTORY_PATH}" apt-get update
chroot "${ROOTFS_DIRECTORY_PATH}" apt-get -y upgrade

if [ "${CUSTOMIZED_RESOLV_CONF}" = "true" ]; then
  rm -rf "${CHROOT_RESOLV_CONF_DIRECTORY_PATH}"
fi

echo "Synchronizing latest filesystem changes..."
sync

echo "Unmounting /dev/pts..."
umount -fl "${ROOTFS_DIRECTORY_PATH}/dev/pts"

echo "Unmounting /proc..."
umount -fl "${ROOTFS_DIRECTORY_PATH}/proc"

echo "Unmounting /sys..."
umount -fl "${ROOTFS_DIRECTORY_PATH}/sys"

echo "Unmounting Raspberry Pi file system..."
umount -v /mnt/raspi-1
umount -v "${ROOTFS_DIRECTORY_PATH}"

echo "Unmounting loop devices..."
kpartx -vd "${IMAGE_FILE_PATH}"

echo "Ensuring that the loop device is not present anymore..."
rm -f "${LOOP_DEVICE_PATH}"
