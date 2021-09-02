#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

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

print_directory_contents_or_warn() {
  DIRECTORY_PATH="${1}"
  if [ -e "$FILE_PATH" ]; then
    echo "-------------------------"
    echo "Contents of ${DIRECTORY_PATH}:"
    find "${DIRECTORY_PATH}" -type f -print -exec echo "-------------------------" \; -exec echo "Contents of "{} \; -exec cat {} \; -exec echo "-------------------------" \;
    echo "-------------------------"
  else
    echo "${DIRECTORY_PATH} doesn't exist"
  fi
}

customize_file_or_directory() {
  SOURCE_PATH="${1}"
  DESTINATION_PATH="${2}"

  if [ -z "${SOURCE_PATH}" ]; then
    echo "Source path is not set. Skipping the customization of ${DESTINATION_PATH}"
    return 0
  fi

  if [ -e "${SOURCE_PATH}" ]; then
    echo "Contents of ${SOURCE_PATH}:"
    print_or_warn "${SOURCE_PATH}"
    echo "Contents of ${DESTINATION_PATH} before overriding it with ${SOURCE_PATH}:"
    print_or_warn "${DESTINATION_PATH}"

    if [ -d "${SOURCE_PATH}" ]; then
      echo "Copying ${SOURCE_PATH} directory contents to ${DESTINATION_PATH}..."
      cp --force --recursive --verbose "${SOURCE_PATH}/." "${DESTINATION_PATH}/"
    else
      echo "Copying ${SOURCE_PATH} to ${DESTINATION_PATH}..."
      cp --force --verbose "${SOURCE_PATH}" "${DESTINATION_PATH}"
    fi
    echo "Contents of ${DESTINATION_PATH} after overriding it with ${SOURCE_PATH}:"
    print_or_warn "${DESTINATION_PATH}"
  else
    echo "Skipping the copy of ${SOURCE_PATH} to ${DESTINATION_PATH} because the source doesn't exist."
    return 0
  fi
}

if ! TEMP="$(getopt -o b: --long build-config: \
  -n 'build' -- "$@")"; then
  echo "Terminating..." >&2
  exit 1
fi
eval set -- "$TEMP"

BUILD_ENVIRONMENT_CONFIGURATION_FILE_PATH=

while true; do
  echo "Decoding parameter ${1}..."
  case "${1}" in
  -b | --build-config)
    BUILD_ENVIRONMENT_CONFIGURATION_FILE_PATH="${2}"
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
cloud-init devel schema --config-file "${CLOUD_INIT_DATASOURCE_CONFIG_DIRECTORY}/user-data.yaml"

IMAGE_ARCHIVE_FILE_PATH="${WORKSPACE_DIRECTORY}"/"${IMAGE_ARCHIVE_FILE_NAME}"

echo "Downloading the OS image from ${IMAGE_URL}..."
[ ! -f "${IMAGE_ARCHIVE_FILE_PATH}" ] && wget -q "${IMAGE_URL}"
[ ! -f "${IMAGE_CHECKSUM_FILE_NAME}" ] && wget -q -O "${IMAGE_CHECKSUM_FILE_NAME}" "${IMAGE_CHECKSUM_URL}"
[ ! -f "${MANIFEST_FILE_NAME}" ] && wget -q -O "${MANIFEST_FILE_NAME}" "${MANIFEST_FILE_URL}"

echo "Verifying the integrity of ${IMAGE_ARCHIVE_FILE_PATH}..."
sha256sum --ignore-missing -c "${IMAGE_CHECKSUM_FILE_NAME}"

print_or_warn "${MANIFEST_FILE_NAME}"

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

echo "Gathering information about ${IMAGE_FILE_PATH}"
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

BOOT_DIRECTORY_PATH="/tmp/raspi-1"
ROOTFS_DIRECTORY_PATH="/tmp/raspi-2"

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

print_or_warn "${ROOTFS_DIRECTORY_PATH}/etc/fstab"

print_or_warn "${BOOT_DIRECTORY_PATH}"
print_or_warn "${BOOT_DIRECTORY_PATH}/README"
print_or_warn "${BOOT_DIRECTORY_PATH}/config.txt"
print_or_warn "${BOOT_DIRECTORY_PATH}/syscfg.txt"
print_or_warn "${BOOT_DIRECTORY_PATH}/usercfg.txt"

CLOUD_INIT_CONFIGURATION_PATH="${ROOTFS_DIRECTORY_PATH}/etc/cloud"
print_or_warn "${CLOUD_INIT_CONFIGURATION_PATH}"
print_or_warn "${CLOUD_INIT_CONFIGURATION_PATH}/cloud.cfg"
print_directory_contents_or_warn "${CLOUD_INIT_CONFIGURATION_PATH}/cloud.cfg.d"

echo "Removing the yaml file extension from cloud init datasource configuration files..."
mv "${CLOUD_INIT_DATASOURCE_CONFIG_DIRECTORY}"/meta-data.yaml "${CLOUD_INIT_DATASOURCE_CONFIG_DIRECTORY}"/meta-data
mv "${CLOUD_INIT_DATASOURCE_CONFIG_DIRECTORY}"/network-config.yaml "${CLOUD_INIT_DATASOURCE_CONFIG_DIRECTORY}"/network-config
mv "${CLOUD_INIT_DATASOURCE_CONFIG_DIRECTORY}"/user-data.yaml "${CLOUD_INIT_DATASOURCE_CONFIG_DIRECTORY}"/user-data

customize_file_or_directory "${CLOUD_INIT_DATASOURCE_CONFIG_DIRECTORY}" "${BOOT_DIRECTORY_PATH}"

customize_file_or_directory "${KERNEL_CMDLINE_SOURCE_FILE_PATH}" "${BOOT_DIRECTORY_PATH}/cmdline.txt"

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
echo "Image file path: ${IMAGE_FILE_PATH}. Image file directory: ${IMAGE_FILE_DIRECTORY_PATH}. Image file name: ${IMAGE_FILE_NAME}. Image file extension: ${IMAGE_FILE_EXTENSION}"

TARGET_IMAGE_FILE_PATH="${IMAGE_FILE_DIRECTORY_PATH}"/"${IMAGE_FILE_NAME}"-"${OS_IMAGE_FILE_TAG}""${IMAGE_FILE_EXTENSION}"
mv -v "${IMAGE_FILE_PATH}" "${TARGET_IMAGE_FILE_PATH}"

ARCHIVE_FILE_EXTENSION=".xz"
echo "Removing image archive (extension: ${ARCHIVE_FILE_EXTENSION}) path leftovers..."
rm -f ./*"${ARCHIVE_FILE_EXTENSION}"

echo "Compressing ${TARGET_IMAGE_FILE_PATH}..."
xz -9 -T6 -v -z "${TARGET_IMAGE_FILE_PATH}"
