#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

# Doesn't follow symlinks, but it's likely expected for most users
SCRIPT_BASENAME="$(basename "${0}")"

echo "This script (${SCRIPT_BASENAME}) has been invoked with: $0 $*"

# shellcheck source=/dev/null
. /common.sh

BUILD_CONFIG_PARAMETER_DESCRIPTION="path to the build configuration file"

usage() {
  echo
  echo "${SCRIPT_BASENAME} - Build OS images."
  echo
  echo "USAGE"
  echo "  ${SCRIPT_BASENAME} [options]"
  echo
  echo "OPTIONS"
  echo "  -b | --build-config: ${BUILD_CONFIG_PARAMETER_DESCRIPTION}"
  echo "  -h | --help: show this help message and exit"
  echo
  echo "EXIT STATUS"
  echo
  echo "  ${EXIT_OK} on correct execution."
  echo "  ${ERR_GENERIC} when an error occurs, and there's no specific error code to handle it."
  echo "  ${ERR_VARIABLE_NOT_DEFINED} when a parameter or a variable is not defined, or empty."
  echo "  ${ERR_MISSING_DEPENDENCY} when a required dependency is missing."
  echo "  ${ERR_ARGUMENT_EVAL_ERROR} when there was an error while evaluating the program options."
  echo "  ${ERR_ARCHIVE_NOT_SUPPORTED} when the archive is not supported."
}

if ! TEMP="$(getopt -o b:h --long build-config:,help \
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
  -h | --help | *)
    usage
    # Ignoring because those are defined in common.sh, and don't need quotes
    # shellcheck disable=SC2086
    exit ${EXIT_OK}
    break
    ;;
  esac
done

check_argument "${BUILD_ENVIRONMENT_CONFIGURATION_FILE_PATH}" "${BUILD_CONFIG_PARAMETER_DESCRIPTION}"

WORKSPACE_DIRECTORY="$(pwd)"
echo "Working directory: ${WORKSPACE_DIRECTORY}"

echo "Loading the build environment configuration from ${BUILD_ENVIRONMENT_CONFIGURATION_FILE_PATH}..."
# shellcheck source=/dev/null
. "${BUILD_ENVIRONMENT_CONFIGURATION_FILE_PATH}"

TEMP_WORKING_DIRECTORY="$(mktemp -d)"
echo "Created a temporary working directory: ${TEMP_WORKING_DIRECTORY}"

DEVICE_CONFIG_DIRECTORY="$(dirname "${BUILD_ENVIRONMENT_CONFIGURATION_FILE_PATH}")"
echo "Device configuration directory path: ${DEVICE_CONFIG_DIRECTORY}"

CLOUD_INIT_DATASOURCE_SOURCE_DIRECTORY_PATH="${DEVICE_CONFIG_DIRECTORY}/cloud-init"
KERNEL_CMDLINE_FILE_PATH="${DEVICE_CONFIG_DIRECTORY}/cmdline.txt"
RASPBERRY_PI_CONFIG_FILE_PATH="${DEVICE_CONFIG_DIRECTORY}/raspberry-pi-config.txt"

echo "Current environment configuration:"
env | sort

if [ -n "${OS_IMAGE_URL}" ]; then
  OS_IMAGE_FILE_PATH="${WORKSPACE_DIRECTORY}"/"$(basename "${OS_IMAGE_URL}")"
  download_file_if_necessary "${OS_IMAGE_URL}" "${OS_IMAGE_FILE_PATH}"

  # We assume there's a checksum file path to verify the downloaded image
  OS_IMAGE_CHECKSUM_FILE_PATH="${WORKSPACE_DIRECTORY}/$(basename "${OS_IMAGE_CHECKSUM_FILE_URL}")"
  echo "Verifying the integrity of the downloaded files..."
  download_file_if_necessary "${OS_IMAGE_CHECKSUM_FILE_URL}" "${OS_IMAGE_CHECKSUM_FILE_PATH}"
  sha256sum --ignore-missing -c "${OS_IMAGE_CHECKSUM_FILE_PATH}"
fi

OS_IMAGE_FILE_TAG="${OS_IMAGE_FILE_TAG:-"generic"}"

if [ "${BUILD_TYPE}" = "${BUILD_TYPE_CUSTOMIZE_IMAGE}" ]; then
  register_qemu_static

  IMAGE_ARCHIVE_FILE_PATH="${OS_IMAGE_FILE_PATH}"
  if ! decompress_file "${IMAGE_ARCHIVE_FILE_PATH}"; then
    RET_CODE=$?
    echo "Error while decompressing ${IMAGE_ARCHIVE_FILE_PATH}. Terminating..."
    exit ${RET_CODE}
  fi

  IMAGE_FILE_PATH="$(pwd)/${OS_IMAGE_FILE_NAME}"
  if [ ! -e "${IMAGE_FILE_PATH}" ]; then
    echo "[ERROR]: The image file does not exist: ${IMAGE_FILE_PATH}. Terminating..."
    # Ignoring because those are defined in common.sh, and don't need quotes
    # shellcheck disable=SC2086
    exit ${ERR_GENERIC}
  fi

  echo "Getting info about the partitions in the image (${IMAGE_FILE_PATH})..."
  PARTITIONS_INFO="$(sfdisk -d "${IMAGE_FILE_PATH}")"
  echo "${PARTITIONS_INFO}"

  # We assume that we want to customize the first partition. On the Ubuntu image for Raspberry Pis and the Raspberry Pi
  # OS image, p1 is mounted as /boot and cointains configuration files.
  BOOT_PARTITION_INDEX="${BOOT_PARTITION_INDEX:-"1"}"
  ROOT_PARTITION_INDEX="${ROOT_PARTITION_INDEX:-"2"}"

  echo "Boot partition index: ${BOOT_PARTITION_INDEX}. Root paritition index: ${ROOT_PARTITION_INDEX}"

  BOOT_PARTITION_OFFSET=$(($(echo "${PARTITIONS_INFO}" | grep "${IMAGE_FILE_PATH}${BOOT_PARTITION_INDEX}" | awk '{print $4-0}') * 512))
  ROOT_PARTITION_OFFSET=$(($(echo "${PARTITIONS_INFO}" | grep "${IMAGE_FILE_PATH}${ROOT_PARTITION_INDEX}" | awk '{print $4-0}') * 512))

  echo "Boot partition offset: ${BOOT_PARTITION_OFFSET}. Root paritition offset: ${ROOT_PARTITION_OFFSET}"

  echo "Currently used loop devices:"
  losetup --list

  echo "Checking if there are stale mounts to clean before mounting ${IMAGE_FILE_PATH}..."
  if losetup -O NAME,BACK-FILE | grep "${IMAGE_FILE_PATH}"; then
    echo "Cleaning stale mounts..."
    losetup -O NAME,BACK-FILE | grep "${IMAGE_FILE_PATH}" | awk '{ print $1 }' | xargs -l1 losetup -d
  else
    echo "There are no stale mounts to clean."
  fi

  echo "Currently used loop devices:"
  losetup --list

  echo "Getting a loop device to mount the root partition..."
  losetup --find

  BOOT_PARTITION_MOUNT_PATH="${TEMP_WORKING_DIRECTORY}/boot"
  mkdir \
    --parents \
    --verbose \
    "${BOOT_PARTITION_MOUNT_PATH}"

  ROOT_PARTITION_MOUNT_PATH="${TEMP_WORKING_DIRECTORY}/root"
  mkdir \
    --parents \
    --verbose \
    "${ROOT_PARTITION_MOUNT_PATH}"

  echo "Mounting the root partition to ${ROOT_PARTITION_MOUNT_PATH}"
  mount -o loop,offset=${ROOT_PARTITION_OFFSET} "${IMAGE_FILE_PATH}" "${ROOT_PARTITION_MOUNT_PATH}"/
  if [ "${BOOT_PARTITION_INDEX}" != "${ROOT_PARTITION_INDEX}" ]; then
    echo "Getting a loop device to mount the boot partition..."
    losetup --find

    echo "Mounting the boot partition to ${BOOT_PARTITION_MOUNT_PATH}"
    mount -o loop,offset=${BOOT_PARTITION_OFFSET},sizelimit=$((ROOT_PARTITION_OFFSET - BOOT_PARTITION_OFFSET)) "${IMAGE_FILE_PATH}" "${BOOT_PARTITION_MOUNT_PATH}"
  fi

  echo "Mounting /sys..."
  if [ "$(mount | grep "${ROOT_PARTITION_MOUNT_PATH}"/sys | awk '{print $3}')" != "${ROOT_PARTITION_MOUNT_PATH}/sys" ]; then
    mount -t sysfs sysfs "${ROOT_PARTITION_MOUNT_PATH}/sys"
  fi

  echo "Mounting /proc..."
  if [ "$(mount | grep "${ROOT_PARTITION_MOUNT_PATH}"/proc | awk '{print $3}')" != "${ROOT_PARTITION_MOUNT_PATH}/proc" ]; then
    mount -t proc proc "${ROOT_PARTITION_MOUNT_PATH}/proc"
  fi

  echo "Mounting /dev"
  mount -o bind /dev "${ROOT_PARTITION_MOUNT_PATH}/dev"

  echo "Mounting /dev/pts..."
  mkdir \
    --parents \
    --verbose \
    "${ROOT_PARTITION_MOUNT_PATH}/dev/pts"

  if [ "$(mount | grep "${ROOT_PARTITION_MOUNT_PATH}"/dev/pts | awk '{print $3}')" != "${ROOT_PARTITION_MOUNT_PATH}/dev/pts" ]; then
    mount -t devpts devpts "${ROOT_PARTITION_MOUNT_PATH}/dev/pts"
  fi

  echo "Current disk space usage:"
  df \
    --human-readable \
    --sync

  print_or_warn "${ROOT_PARTITION_MOUNT_PATH}/var/lib/cloud"

  print_or_warn "${BOOT_PARTITION_MOUNT_PATH}/cmdline.txt"

  print_or_warn "${BOOT_PARTITION_MOUNT_PATH}/config.txt"
  print_or_warn "${BOOT_PARTITION_MOUNT_PATH}/syscfg.txt"
  print_or_warn "${BOOT_PARTITION_MOUNT_PATH}/usercfg.txt"

  CLOUD_INIT_CONFIGURATION_PATH="${ROOT_PARTITION_MOUNT_PATH}/etc/cloud"
  print_or_warn "${CLOUD_INIT_CONFIGURATION_PATH}"
  print_or_warn "${CLOUD_INIT_CONFIGURATION_PATH}/cloud.cfg"

  print_or_warn "${ROOT_PARTITION_MOUNT_PATH}/etc/fstab"
  print_or_warn "${ROOT_PARTITION_MOUNT_PATH}/etc/ld.so.preload"

  CLOUD_INIT_CONFIGURATION_DIRECTORY_PATH="${CLOUD_INIT_CONFIGURATION_PATH}/cloud.cfg.d"
  if [ -e "${CLOUD_INIT_CONFIGURATION_DIRECTORY_PATH}" ]; then
    echo "Getting contents of the cloud-init configuration files from ${CLOUD_INIT_CONFIGURATION_DIRECTORY_PATH}..."
    find "${CLOUD_INIT_CONFIGURATION_DIRECTORY_PATH}" -type f -print -exec echo \; -exec cat {} \; -exec echo \;
  else
    echo "The cloud-init configuration directory ${CLOUD_INIT_CONFIGURATION_DIRECTORY_PATH} does not exist"
  fi

  if [ -e "${CLOUD_INIT_DATASOURCE_SOURCE_DIRECTORY_PATH}" ]; then
    setup_cloud_init_nocloud_datasource "${CLOUD_INIT_DATASOURCE_SOURCE_DIRECTORY_PATH}" "${BOOT_PARTITION_MOUNT_PATH}"
  fi

  copy_file_if_available "${KERNEL_CMDLINE_FILE_PATH}" "${BOOT_PARTITION_MOUNT_PATH}/cmdline.txt"
  copy_file_if_available "${RASPBERRY_PI_CONFIG_FILE_PATH}" "${BOOT_PARTITION_MOUNT_PATH}/config.txt"

  if [ "${ENABLE_RASPBERRY_PI_OS_SSH}" = "true" ]; then
    echo "Enabling SSH on Raspberry Pi OS..."
    # https://www.raspberrypi.com/documentation/computers/configuration.html#ssh-or-ssh-txt
    touch "${BOOT_PARTITION_MOUNT_PATH}/ssh.txt"
  fi

  if [ "${BUILD_DISTRIBUTION}" = "ubuntu" ]; then
    CHROOT_RESOLV_CONF_PATH="${ROOT_PARTITION_MOUNT_PATH}"/run/systemd/resolve/stub-resolv.conf
    initialize_resolv_conf "${CHROOT_RESOLV_CONF_PATH}"
  fi

  echo "Pinging an external domain to test name resolution and network connectivity..."
  chroot "${ROOT_PARTITION_MOUNT_PATH}" ping -c 3 google.com

  if [ "${UPGRADE_APT_PACKAGES-}" = "true" ]; then
    echo "Updating the APT index and upgrading the system..."
    chroot "${ROOT_PARTITION_MOUNT_PATH}" apt-get update
    chroot "${ROOT_PARTITION_MOUNT_PATH}" apt-get -y upgrade
  fi

  echo "Installed APT packages:"
  chroot "${ROOT_PARTITION_MOUNT_PATH}" dpkg -l | sort

  if [ "${CUSTOMIZED_RESOLV_CONF}" = "true" ]; then
    rm \
      --force \
      --recursive \
      --verbose \
      "$(dirname "${CHROOT_RESOLV_CONF_PATH}")"
  fi

  echo "Synchronizing latest filesystem changes..."
  sync

  echo "Current disk space usage:"
  df \
    --human-readable \
    --sync

  echo "Unmounting file systems..."
  # We might have "broken" mounts in the mix that point at a deleted image (in case of some odd
  # build errors). So our "mount" output can look like this:
  #
  #     /path/to/our/image.img (deleted) on /path/to/our/mount type ext4 (rw)
  #     /path/to/our/image.img on /path/to/our/mount type ext4 (rw)
  #     /path/to/our/image.img on /path/to/our/mount/boot type vfat (rw)
  #
  # so we split on "on" first, then do a whitespace split to get the actual mounted directory.
  # Also we sort in reverse to get the deepest mounts first.
  for m in $(mount | grep "${TEMP_WORKING_DIRECTORY}" | awk -F " on " '{print $2}' | awk '{print $1}' | sort -r); do
    echo "Unmounting ${m}..."
    umount "${m}"
  done

  echo "Adding the ${OS_IMAGE_FILE_TAG} tag to the image file..."
  IMAGE_FILE_EXTENSION=".${IMAGE_FILE_PATH##*.}"
  IMAGE_FILE_DIRECTORY_PATH="$(dirname -- "${IMAGE_FILE_PATH}")"
  IMAGE_FILE_NAME="$(basename -- "${IMAGE_FILE_PATH}" "${IMAGE_FILE_EXTENSION}")"
  echo "Image file path: ${IMAGE_FILE_PATH}. Image file directory: ${IMAGE_FILE_DIRECTORY_PATH}. Image file name: ${IMAGE_FILE_NAME}. Image file extension: ${IMAGE_FILE_EXTENSION}"

  TARGET_IMAGE_FILE_NAME="${IMAGE_FILE_NAME}"-"${OS_IMAGE_FILE_TAG}""${IMAGE_FILE_EXTENSION}"
  TARGET_IMAGE_FILE_PATH="${IMAGE_FILE_DIRECTORY_PATH}"/"${TARGET_IMAGE_FILE_NAME}"
  mv -v "${IMAGE_FILE_PATH}" "${TARGET_IMAGE_FILE_PATH}"
elif [ "${BUILD_TYPE}" = "${BUILD_TYPE_CIDATA_ISO}" ]; then
  setup_cloud_init_nocloud_datasource "${CLOUD_INIT_DATASOURCE_SOURCE_DIRECTORY_PATH}" "${TEMP_WORKING_DIRECTORY}"

  TARGET_IMAGE_FILE_NAME="cloud-init-datasource-${OS_IMAGE_FILE_TAG}.iso"
  TARGET_IMAGE_FILE_PATH="${WORKSPACE_DIRECTORY}/${TARGET_IMAGE_FILE_NAME}"
  generate_cidata_iso "${TEMP_WORKING_DIRECTORY}" "${TARGET_IMAGE_FILE_PATH}"
else
  echo "[ERROR]: Unsupported build type. Terminating..."
  # Ignoring because those are defined in common.sh, and don't need quotes
  # shellcheck disable=SC2086
  exit ${ERR_ARGUMENT_EVAL_ERROR}
fi

compress_file "${TARGET_IMAGE_FILE_PATH}"
CUSTOMIZED_COMPRESSED_IMAGE_FILE_NAME="$(basename "${COMPRESSED_FILE_PATH}")"

# Store metadata about the customization process
BUILD_RESULTS_FILE_PATH="${WORKSPACE_DIRECTORY}/results.out"
echo "Saving build metadata to ${BUILD_RESULTS_FILE_PATH}..."
# We override any existing content in the build results file
{
  echo "CUSTOMIZED_IMAGE_FILE_NAME=${TARGET_IMAGE_FILE_NAME}"
  echo "CUSTOMIZED_COMPRESSED_IMAGE_FILE_NAME=${CUSTOMIZED_COMPRESSED_IMAGE_FILE_NAME}"
} >"${BUILD_RESULTS_FILE_PATH}"

echo "Contents of ${BUILD_RESULTS_FILE_PATH}:"
cat "${BUILD_RESULTS_FILE_PATH}"

echo "Deleting the temporary working directory (${TEMP_WORKING_DIRECTORY})..."
rm \
  --force \
  --recursive \
  "${TEMP_WORKING_DIRECTORY}"
