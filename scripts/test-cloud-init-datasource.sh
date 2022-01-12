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

install_dependencies() {
  echo "Ensure test dependencies are installed..."
  apt-get -qy update
  apt-get -qy install \
    cloud-init
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

install_dependencies

if ! [ -e "${DATASOURCE_IMAGE_PATH}" ]; then
  echo "[ERROR]: ${DATASOURCE_IMAGE_PATH} doesn't exist. Terminating..."
  exit ${ERR_ARGUMENT_EVAL_ERROR}
else
  echo "Testing cloud-init datasource image: ${DATASOURCE_IMAGE_PATH}"
fi

DATASOURCE_ISO_MOUNT_PATH="$(mktemp -d)"
sudo mount -o loop "${DATASOURCE_IMAGE_PATH}" "${DATASOURCE_ISO_MOUNT_PATH}"

cloud-init --version
cloud-init clean
cloud-init init --file "${DATASOURCE_ISO_MOUNT_PATH}/user-data" --file "${DATASOURCE_ISO_MOUNT_PATH}/meta-data"
cloud-init modules --file "${DATASOURCE_ISO_MOUNT_PATH}/user-data" --file "${DATASOURCE_ISO_MOUNT_PATH}/meta-data"
cloud-init status
