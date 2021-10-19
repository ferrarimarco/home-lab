#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

echo "This script has been invoked with: $0 $*"

# shellcheck disable=SC1091
. common.sh

# Doesn't follow symlinks, but it's likely expected for most users
SCRIPT_BASENAME="$(basename "${0}")"

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

echo "Checking if the necessary parameters are set..."
check_argument "${BUILD_ENVIRONMENT_CONFIGURATION_FILE_PATH}" "${BUILD_CONFIG_PARAMETER_DESCRIPTION}"

WORKSPACE_DIRECTORY="$(pwd)"
echo "Working directory: ${WORKSPACE_DIRECTORY}"

echo "Loading the build environment configuration from ${BUILD_ENVIRONMENT_CONFIGURATION_FILE_PATH}..."
# shellcheck source=/dev/null
. "${BUILD_ENVIRONMENT_CONFIGURATION_FILE_PATH}"

IMAGE_ARCHIVE_FILE_PATH="${WORKSPACE_DIRECTORY}"/"${IMAGE_ARCHIVE_FILE_NAME}"

echo "Downloading the OS image from ${IMAGE_URL}..."
[ ! -f "${IMAGE_ARCHIVE_FILE_PATH}" ] && wget -q "${IMAGE_URL}"
[ ! -f "${IMAGE_CHECKSUM_FILE_NAME}" ] && wget -q -O "${IMAGE_CHECKSUM_FILE_NAME}" "${IMAGE_CHECKSUM_URL}"

echo "Verifying the integrity of ${IMAGE_ARCHIVE_FILE_PATH}..."
sha256sum --ignore-missing -c "${IMAGE_CHECKSUM_FILE_NAME}"

IMAGE_ARCHIVE_FILE_EXTENSION="${IMAGE_ARCHIVE_FILE_PATH##*.}"

if [ "${IMAGE_ARCHIVE_FILE_EXTENSION}" = "xz" ]; then
  echo "${IMAGE_ARCHIVE_FILE_PATH} is a compressed file."
  IMAGE_FILE_NAME="$(basename "${IMAGE_ARCHIVE_FILE_PATH}" ".${IMAGE_ARCHIVE_FILE_EXTENSION}")"
  IMAGE_FILE_PATH="${WORKSPACE_DIRECTORY}/${IMAGE_FILE_NAME}"

  if [ ! -f "${IMAGE_FILE_PATH}" ]; then
    echo "Extracting contents of ${IMAGE_ARCHIVE_FILE_PATH}..."
    xz -d -T0 -v "${IMAGE_ARCHIVE_FILE_PATH}"

    echo "Deleting ${IMAGE_ARCHIVE_FILE_PATH} if necessary..."
    [ -f "${IMAGE_ARCHIVE_FILE_PATH}" ] && rm -f "${IMAGE_ARCHIVE_FILE_PATH}"
  else
    echo "${IMAGE_FILE_PATH} already exists, skipping extraction..."
  fi
else
  echo "${IMAGE_ARCHIVE_FILE_PATH} archive is not supported. Terminating..."
  # Ignoring because those are defined in common.sh, and don't need quotes
  # shellcheck disable=SC2086
  exit ${ERR_ARCHIVE_NOT_SUPPORTED}
fi

echo "Currently used loop devices:"
losetup --list

echo "Checking if there are stale mounts to clean before mounting ${IMAGE_FILE_PATH}..."
if losetup -O NAME,BACK-FILE | grep "${IMAGE_FILE_PATH}"; then
  echo "Cleaning stale mounts..."
  losetup -O NAME,BACK-FILE | grep "${IMAGE_FILE_PATH}" | awk '{ print $1 }' | xargs -l1 losetup -d
else
  echo "There are no stale mounts to clean."
fi

echo "Mapping ${IMAGE_FILE_PATH} to loop devices..."
kpartx -asv "${IMAGE_FILE_PATH}"

echo "Currently used loop devices:"
losetup --list

BOOT_DIRECTORY_PATH="/tmp/bootfs"
ROOTFS_DIRECTORY_PATH="/tmp/rootfs"

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

DEVICE_CONFIG_DIRECTORY="$(dirname "${BUILD_ENVIRONMENT_CONFIGURATION_FILE_PATH}")"
echo "Device configuration directory: ${DEVICE_CONFIG_DIRECTORY}"

setup_cloud_init_nocloud_datasource "${DEVICE_CONFIG_DIRECTORY}/cloud-init" "${BOOT_DIRECTORY_PATH}"

copy_file_if_exists "${DEVICE_CONFIG_DIRECTORY}/kernel/cmdline.txt" "${BOOT_DIRECTORY_PATH}/cmdline.txt"

echo "Synchronizing latest filesystem changes..."
sync

echo "Current disk space usage:"
df -h

echo "Unmounting file systems..."
umount -v "${BOOT_DIRECTORY_PATH}"
umount -v "${ROOTFS_DIRECTORY_PATH}"

echo "Deleting mount directories..."
rm -rf "${BOOT_DIRECTORY_PATH}"
rm -rf "${ROOTFS_DIRECTORY_PATH}"

echo "Deleting loop devices where ${IMAGE_FILE_PATH} was mapped..."
kpartx -svd "${IMAGE_FILE_PATH}"

echo "Removing the ${LOOP_DEVICE_PATH} loop device..."
rm -f "${LOOP_DEVICE_PATH}"

echo "Adding the ${OS_IMAGE_FILE_TAG} tag to the image file..."
IMAGE_FILE_EXTENSION=".${IMAGE_FILE_PATH##*.}"
IMAGE_FILE_DIRECTORY_PATH="$(dirname -- "${IMAGE_FILE_PATH}")"
IMAGE_FILE_NAME="$(basename -- "${IMAGE_FILE_PATH}" "${IMAGE_FILE_EXTENSION}")"
echo "Image file path: ${IMAGE_FILE_PATH}. Image file directory: ${IMAGE_FILE_DIRECTORY_PATH}. Image file name: ${IMAGE_FILE_NAME}. Image file extension: ${IMAGE_FILE_EXTENSION}"

TARGET_IMAGE_FILE_NAME="${IMAGE_FILE_NAME}"-"${OS_IMAGE_FILE_TAG}""${IMAGE_FILE_EXTENSION}"
TARGET_IMAGE_FILE_PATH="${IMAGE_FILE_DIRECTORY_PATH}"/"${TARGET_IMAGE_FILE_NAME}"
mv -v "${IMAGE_FILE_PATH}" "${TARGET_IMAGE_FILE_PATH}"

# Store useful metadata about the customization process
BUILD_RESULTS_FILE_PATH="${IMAGE_FILE_DIRECTORY_PATH}"/results.out

echo "CUSTOMIZED_IMAGE_FILE_NAME=${TARGET_IMAGE_FILE_NAME}" >>"${BUILD_RESULTS_FILE_PATH}"

ARCHIVE_FILE_EXTENSION=".xz"
echo "Removing image archive (extension: ${ARCHIVE_FILE_EXTENSION}) path leftovers..."
rm -f ./*"${ARCHIVE_FILE_EXTENSION}"

echo "Compressing ${TARGET_IMAGE_FILE_PATH}..."
xz -9 \
  --compress \
  --threads=0 \
  --verbose \
  "${TARGET_IMAGE_FILE_PATH}"

echo "CUSTOMIZED_COMPRESSED_IMAGE_FILE_NAME=${TARGET_IMAGE_FILE_NAME}${ARCHIVE_FILE_EXTENSION}" >>"${BUILD_RESULTS_FILE_PATH}"
