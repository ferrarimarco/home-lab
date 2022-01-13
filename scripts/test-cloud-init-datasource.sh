#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

# Doesn't follow symlinks, but it's likely expected for most users
SCRIPT_BASENAME="$(basename "${0}")"

echo "This script (${SCRIPT_BASENAME}) has been invoked with: $0 $*"

EXIT_OK=0
ERR_GENERIC=1
ERR_VARIABLE_NOT_DEFINED=2
ERR_MISSING_DEPENDENCY=3
ERR_ARGUMENT_EVAL_ERROR=4
ERR_ARCHIVE_NOT_SUPPORTED=5

decompress_file() {
  FILE_TO_DECOMPRESS_PATH="${1}"

  FILE_TO_DECOMPRESS_EXTENSION="${FILE_TO_DECOMPRESS_PATH##*.}"

  echo "Decompressing ${FILE_TO_DECOMPRESS_PATH}..."
  if [ "${FILE_TO_DECOMPRESS_EXTENSION}" = "xz" ]; then
    xz -d --keep -T0 -v "${FILE_TO_DECOMPRESS_PATH}"
  else
    echo "${IMAGE_ARCHIVE_FILE_PATH} archive is not supported. Terminating..."
    return ${ERR_ARCHIVE_NOT_SUPPORTED}
  fi

  DECOMPRESSED_FILE_NAME="$(basename "${FILE_TO_DECOMPRESS_PATH}" ".${FILE_TO_DECOMPRESS_EXTENSION}")"
  DECOMPRESSED_FILE_PATH="$(dirname "${FILE_TO_DECOMPRESS_PATH}")/${DECOMPRESSED_FILE_NAME}"
}

install_dependencies() {
  echo "Ensure test dependencies are installed..."
  sudo apt-get -qy update
  sudo apt-get -qy install \
    cloud-image-utils \
    cloud-init \
    kpartx \
    xz-utils
}

DATASOURCE_IMAGE_PATH_DESCRIPTION="path to the cloud-init datasource image to test"

usage() {
  echo
  echo "${SCRIPT_BASENAME} - Test cloud-init datasources."
  echo
  echo "USAGE"
  echo "  ${SCRIPT_BASENAME} [options]"
  echo
  echo "OPTIONS"
  echo "  -d | --datasource-image-path: ${DATASOURCE_IMAGE_PATH_DESCRIPTION}"
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

if ! TEMP="$(getopt -o d:h --long datasource-image-path:,help \
  -n 'build' -- "$@")"; then
  echo "Terminating..." >&2
  exit 1
fi
eval set -- "$TEMP"

DATASOURCE_IMAGE_PATH=

while true; do
  echo "Decoding parameter ${1}..."
  case "${1}" in
  -d | --datasource-image-path)
    DATASOURCE_IMAGE_PATH="${2}"
    shift 2
    ;;
  --)
    echo "No more parameters to decode"
    shift
    break
    ;;
  -h | --help | *)
    usage
    exit ${EXIT_OK}
    break
    ;;
  esac
done

SOURCE_DIRECTORY_PATH="$(dirname "${DATASOURCE_IMAGE_PATH}")"
echo "Contents of ${SOURCE_DIRECTORY_PATH}:"
ls -alh "${SOURCE_DIRECTORY_PATH}"

install_dependencies

if ! [ -r "${DATASOURCE_IMAGE_PATH}" ]; then
  echo "[ERROR]: ${DATASOURCE_IMAGE_PATH} doesn't exist. Terminating..."
  exit ${ERR_ARGUMENT_EVAL_ERROR}
else
  echo "Testing cloud-init datasource image: ${DATASOURCE_IMAGE_PATH}"
fi

decompress_file "${DATASOURCE_IMAGE_PATH}"

echo "Gathering information about ${DECOMPRESSED_FILE_PATH}..."
isoinfo -d -i "${DECOMPRESSED_FILE_PATH}"

echo "Mapping ${DECOMPRESSED_FILE_PATH} to loop devices..."
sudo kpartx -asv "${DECOMPRESSED_FILE_PATH}"

echo "Currently used loop devices:"
sudo losetup --list

DATASOURCE_ISO_MOUNT_PATH="$(mktemp -d)"
sudo mount -o loop,ro "${DECOMPRESSED_FILE_PATH}" "${DATASOURCE_ISO_MOUNT_PATH}"

echo "Currently attached block devices:"
sudo lsblk -o name,mountpoint,label,size,uuid

echo "Currently mounted file systems:"
mount

echo "Contents of ${DATASOURCE_ISO_MOUNT_PATH}:"
ls -alh "${DATASOURCE_ISO_MOUNT_PATH}"

CLOUD_INIT_CONFIG_FILE_PATH="/etc/cloud/cloud.cfg"

echo "Appending configuration to the cloud-init configuration file (${CLOUD_INIT_CONFIG_FILE_PATH})..."
cat <<EOF >>"${CLOUD_INIT_CONFIG_FILE_PATH}"
datasource:
  NoCloud:
    seedfrom: "${DATASOURCE_ISO_MOUNT_PATH}"/
EOF

echo "Current cloud-init configuration (${CLOUD_INIT_CONFIG_FILE_PATH}):"
cat "${CLOUD_INIT_CONFIG_FILE_PATH}"

echo "Cloud-init version: $(cloud-init --version)"
cloud-init status --long
echo "Cleanining cloud-init status..."
sudo cloud-init clean --logs
cloud-init status --long

echo "Running cloud-init init..."
sudo cloud-init init --local

echo "Running cloud-init modules..."
sudo cloud-init modules
cloud-init status --long

echo "Contents of cloud-init log:"
cat /var/log/cloud-init.log
