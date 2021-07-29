#!/usr/bin/env sh

set -o nounset
set -o errexit

echo "This script has been invoked with: $0 $*"

print_or_warn() {
  FILE_PATH="${1}"
  if [ -e "$FILE_PATH" ]; then
    echo "-------------------------"
    echo "Contents of ${FILE_PATH} ($(ls -alhR "${FILE_PATH}")):"
    if [ -f "$FILE_PATH" ]; then
      cat "${FILE_PATH}"
    fi
    echo "-------------------------"
  else
    echo "${FILE_PATH} doesn't exist"
  fi
}

customize_file() {
  SOURCE_PATH="${1}"
  DESTINATION_PATH="${2}"

  if [ -z "${SOURCE_PATH}" ]; then
    echo "Source file path is not set. Skipping the customization of ${DESTINATION_PATH}"
    return 0
  fi

  if [ -e "${SOURCE_PATH}" ]; then
    print_or_warn "${SOURCE_PATH}"
    echo "Contents of ${DESTINATION_PATH} before overriding it with ${SOURCE_PATH}:"
    print_or_warn "${DESTINATION_PATH}"
    echo "Copying ${SOURCE_PATH} to ${DESTINATION_PATH}..."
    cp -f "${SOURCE_PATH}" "${DESTINATION_PATH}"
  else
    echo "Skipping the copy of ${SOURCE_PATH} to ${DESTINATION_PATH} because the source doesn't exist."
  fi
  print_or_warn "${SOURCE_PATH}"
}

if ! TEMP="$(getopt -o b:m:n:u:t: --long build-config:,cloud-init-meta-data:,cloud-init-network-config:,cloud-init-user-data:,os-image-tag: \
  -n 'build' -- "$@")"; then
  echo "Terminating..." >&2
  exit 1
fi
eval set -- "$TEMP"

BUILD_ENVIRONMENT_CONFIGURATION_FILE_PATH=
CLOUD_INIT_META_DATA_FILE_PATH=
CLOUD_INIT_NETWORK_CONFIG_FILE_PATH=
CLOUD_INIT_USER_DATA_FILE_PATH=
OS_IMAGE_FILE_TAG="generic"

while true; do
  echo "Decoding parameter ${1}..."
  case "${1}" in
  -b | --build-config)
    BUILD_ENVIRONMENT_CONFIGURATION_FILE_PATH="${2}"
    shift 2
    ;;
  -m | --cloud-init-meta-data)
    CLOUD_INIT_META_DATA_FILE_PATH="${2}"
    shift 2
    ;;
  -n | --cloud-init-network-config)
    CLOUD_INIT_NETWORK_CONFIG_FILE_PATH="${2}"
    shift 2
    ;;
  -u | --cloud-init-user-data)
    CLOUD_INIT_USER_DATA_FILE_PATH="${2}"
    shift 2
    ;;
  -t | --os-image-tag)
    OS_IMAGE_FILE_TAG="${2}"
    shift 2
    ;;
  --)
    echo "No more parameters to decode"
    shift
    break
    ;;
  *) break ;;
  esac
done

WORKSPACE_DIRECTORY="$(pwd)"
echo "Working directory: ${WORKSPACE_DIRECTORY}"

echo "Loading the build environment configuration from ${BUILD_ENVIRONMENT_CONFIGURATION_FILE_PATH}..."
# shellcheck source=/dev/null
. "${BUILD_ENVIRONMENT_CONFIGURATION_FILE_PATH}"

echo "Current environment configuration:"
env | sort

echo "Validating cloud-init configuration file..."
cloud-init devel schema --config-file "${CLOUD_INIT_USER_DATA_FILE_PATH}"

IMAGE_ARCHIVE_FILE_PATH="${WORKSPACE_DIRECTORY}"/"${IMAGE_ARCHIVE_FILE_NAME}"

echo "Downloading the OS image from ${IMAGE_URL}..."
[ ! -f "${IMAGE_ARCHIVE_FILE_PATH}" ] && wget -q "${IMAGE_URL}"
[ ! -f "${IMAGE_CHECKSUM_FILE_NAME}" ] && wget -q -O "${IMAGE_CHECKSUM_FILE_NAME}" "${IMAGE_CHECKSUM_URL}"

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
  xz -d -T0 -v "${IMAGE_ARCHIVE_FILE_PATH}"

  echo "Deleting ${IMAGE_ARCHIVE_FILE_PATH} if necessary..."
  [ -f "${IMAGE_ARCHIVE_FILE_PATH}" ] && rm -f "${IMAGE_ARCHIVE_FILE_PATH}"
else
  echo "${IMAGE_FILE_PATH} already exists, skipping extraction..."
fi

echo "Gathering information about ${IMAGE_ARCHIVE_FILE_PATH}"
fdisk -l "${IMAGE_FILE_PATH}"

echo "Currently used loop devices:"
losetup --all

echo "Checking if there are stale mounts to clean (mounting ${IMAGE_FILE_PATH})..."
if losetup -O NAME,BACK-FILE | grep "${IMAGE_FILE_PATH}"; then
  echo "Cleaning stale mounts..."
  losetup -O NAME,BACK-FILE | grep "${IMAGE_FILE_PATH}" | awk '{ print $1 }' | xargs -l1 losetup -d
else
  echo "There are no stale mounts to clean."
fi

echo "Mounting loop devices from ${IMAGE_FILE_PATH}..."
kpartx -asv "${IMAGE_FILE_PATH}"

echo "Currently used loop devices (after mounting the image):"
losetup --all

BOOT_DIRECTORY_PATH="/mnt/raspi-1"
ROOTFS_DIRECTORY_PATH="/mnt/raspi-2"

echo "Creating directories to mount loop devices (${BOOT_DIRECTORY_PATH}, ${ROOTFS_DIRECTORY_PATH})..."
mkdir -p "${BOOT_DIRECTORY_PATH}"
mkdir -p "${ROOTFS_DIRECTORY_PATH}"

LOOP_DEVICE_PATH="$(losetup -O NAME,BACK-FILE | grep "${IMAGE_FILE_PATH}" | awk '{ print $1 }')"
LOOP_DEVICE_NAME="$(basename "${LOOP_DEVICE_PATH}")"
LOOP_DEVICE_PARTITION_PREFIX=/dev/mapper/"${LOOP_DEVICE_NAME}"

echo "Gathering information about the partitions to mount..."
blkid "${LOOP_DEVICE_PATH}" "${LOOP_DEVICE_PARTITION_PREFIX}"p*

echo "Mounting partitions from ${LOOP_DEVICE_PATH} (prefix: ${LOOP_DEVICE_PARTITION_PREFIX})"
mount -v "${LOOP_DEVICE_PARTITION_PREFIX}"p1 "${BOOT_DIRECTORY_PATH}"
mount -v "${LOOP_DEVICE_PARTITION_PREFIX}"p2 "${ROOTFS_DIRECTORY_PATH}"

echo "Current disk space usage:"
df -h

print_or_warn "${BOOT_DIRECTORY_PATH}"
print_or_warn "${ROOTFS_DIRECTORY_PATH}/var/lib/cloud"

echo "Customizing ${ROOTFS_DIRECTORY_PATH}..."

print_or_warn "${BOOT_DIRECTORY_PATH}/cmdline.txt"

print_or_warn "${BOOT_DIRECTORY_PATH}/config.txt"
print_or_warn "${BOOT_DIRECTORY_PATH}/syscfg.txt"
print_or_warn "${BOOT_DIRECTORY_PATH}/usercfg.txt"

CLOUD_INIT_CONFIGURATION_PATH="${ROOTFS_DIRECTORY_PATH}/etc/cloud"
print_or_warn "${CLOUD_INIT_CONFIGURATION_PATH}"
print_or_warn "${CLOUD_INIT_CONFIGURATION_PATH}/cloud.cfg"

print_or_warn "${ROOTFS_DIRECTORY_PATH}/etc/fstab"

echo "Getting contents of the cloud-init configuration files..."
find "${CLOUD_INIT_CONFIGURATION_PATH}/cloud.cfg.d" -type f -print -exec echo \; -exec cat {} \; -exec echo \;

customize_file "${CLOUD_INIT_USER_DATA_FILE_PATH}" "${BOOT_DIRECTORY_PATH}/user-data"
customize_file "${CLOUD_INIT_META_DATA_FILE_PATH}" "${BOOT_DIRECTORY_PATH}/meta-data"
customize_file "${CLOUD_INIT_NETWORK_CONFIG_FILE_PATH}" "${BOOT_DIRECTORY_PATH}/network-config"

echo "Synchronizing latest filesystem changes..."
sync

echo "Unmounting Raspberry Pi file system..."
umount -v "${BOOT_DIRECTORY_PATH}"
umount -v "${ROOTFS_DIRECTORY_PATH}"

echo "Unmounting loop devices..."
kpartx -vd "${IMAGE_FILE_PATH}"

echo "Ensuring that the loop device is not present anymore..."
rm -f "${LOOP_DEVICE_PATH}"

echo "Adding the ${OS_IMAGE_FILE_TAG} tag to the image file..."

IMAGE_FILE_EXTENSION=".${IMAGE_FILE_PATH##*.}"
IMAGE_FILE_DIRECTORY_PATH="$(dirname -- "${IMAGE_FILE_PATH}")"
IMAGE_FILE_NAME="$(basename -- "${IMAGE_FILE_PATH}" "${IMAGE_FILE_EXTENSION}")"
echo "Image file path: ${IMAGE_FILE_PATH}.Image file directory: ${IMAGE_FILE_DIRECTORY_PATH}. Image file name: ${IMAGE_FILE_NAME}. Image file extension: ${IMAGE_FILE_EXTENSION}"

TARGET_IMAGE_FILE_PATH="${IMAGE_FILE_DIRECTORY_PATH}"/"${IMAGE_FILE_NAME}"-"${OS_IMAGE_FILE_TAG}""${IMAGE_FILE_EXTENSION}"
mv -v "${IMAGE_FILE_PATH}" "${TARGET_IMAGE_FILE_PATH}"

ARCHIVE_FILE_EXTENSION=".xz"
echo "Removing image archive (extension: ${ARCHIVE_FILE_EXTENSION}) path leftovers..."
rm -f ./*"${ARCHIVE_FILE_EXTENSION}"

echo "Compressing ${TARGET_IMAGE_FILE_PATH}..."
xz -9 -T6 -v -z "${TARGET_IMAGE_FILE_PATH}"
