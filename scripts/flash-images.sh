#!/usr/bin/env sh

set -o errexit
set -o nounset

# Doesn't follow symlinks, but it's likely expected for most users
SCRIPT_BASENAME="$(basename "${0}")"

echo "This script (${SCRIPT_BASENAME}) has been invoked with: $0 $*"

# shellcheck disable=SC1091
. scripts/common.sh

# Doesn't follow symlinks, but it's likely expected for most users
SCRIPT_BASENAME="$(basename "${0}")"

DRIVE_TO_FLASH_DESCRIPTION="Drive to flash"
IMAGE_URL_DESCRIPTION="URL pointing to the image to download and flash."

usage() {
  echo
  echo "${SCRIPT_BASENAME} - Flash OS and other images."
  echo
  echo "USAGE"
  echo "  ${SCRIPT_BASENAME} [options]"
  echo
  echo "OPTIONS"
  echo "  -h $(is_linux && echo "| --help"): ${HELP_DESCRIPTION}"
  echo "  -f $(is_linux && echo "| --drive-to-flash"): ${DRIVE_TO_FLASH_DESCRIPTION}"
  echo "  -i $(is_linux && echo "| --image-url"): ${IMAGE_URL_DESCRIPTION}"

  print_exit_statuses
}

LONG_OPTIONS="help,drive-to-flash:,image-url:"
SHORT_OPTIONS="d:hi:"

echo "Checking if the necessary dependencies are available..."
check_exec_dependency "curl"
check_exec_dependency "dd"
check_exec_dependency "getopt"

if is_macos; then
  check_exec_dependency "diskutil"
  check_exec_dependency "sync"
fi

# BSD getopt (bundled in MacOS) doesn't support long options, and has different parameters than GNU getopt
if is_linux; then
  TEMP="$(getopt -o "${SHORT_OPTIONS}" --long "${LONG_OPTIONS}" -n "${SCRIPT_BASENAME}" -- "$@")"
elif is_macos; then
  TEMP="$(getopt "${SHORT_OPTIONS} --" "$@")"
  echo "WARNING: Long command line options are not supported on this system."
fi
RET_CODE=$?
if [ ! ${RET_CODE} ]; then
  echo "Error while evaluating command options. Terminating..."
  # Ignoring SC2086 because those are defined in common.sh, and don't need quotes
  # shellcheck disable=SC2086
  exit ${ERR_ARGUMENT_EVAL_ERROR}
fi
eval set -- "${TEMP}"

DRIVE_TO_FLASH=
IMAGE_URL=

while true; do
  case "${1}" in
  -d | --drive-to-flash)
    DRIVE_TO_FLASH="${2}"
    shift 2
    break
    ;;
  -i | --image-url)
    IMAGE_URL="${2}"
    shift 2
    break
    ;;
  --)
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

check_argument "${DRIVE_TO_FLASH}" "${DRIVE_TO_FLASH_DESCRIPTION}"
check_argument "${IMAGE_URL}" "${IMAGE_URL_DESCRIPTION}"

IMAGE_FILE_NAME="$(basename "${IMAGE_URL}")"
IMAGE_FILE_PATH="$(pwd)/${IMAGE_FILE_NAME}"

if [ ! -f "${IMAGE_FILE_PATH}" ]; then
  echo "Downloading the image from ${IMAGE_URL} to ${IMAGE_FILE_PATH}..."
  curl -O "${IMAGE_URL}"
else
  echo "${IMAGE_FILE_PATH} already exists. Skipping download..."
fi

IMAGE_FILE_EXTENSION="${IMAGE_FILE_PATH##*.}"

if [ "${IMAGE_FILE_EXTENSION}" = "xz" ]; then
  echo "${IMAGE_FILE_PATH} is a compressed file."
  IMAGE_FILE_NAME="$(basename "${IMAGE_FILE_PATH}" ".${IMAGE_FILE_EXTENSION}")"

  if [ ! -f "${IMAGE_FILE_PATH}" ]; then
    echo "Extracting contents of ${IMAGE_FILE_PATH}..."
    xz -d -T0 -v "${IMAGE_FILE_PATH}"
  else
    echo "${IMAGE_FILE_PATH} already exists, skipping extraction..."
  fi
  DECOMPRESSED_IMAGE_FILE_PATH="$(dirname "${IMAGE_FILE_PATH}")/${IMAGE_FILE_NAME}"
  IMAGE_FILE_PATH="${DECOMPRESSED_IMAGE_FILE_PATH}"
else
  echo "${IMAGE_FILE_PATH} archive is not supported. Terminating..."
  # Ignoring because those are defined in common.sh, and don't need quotes
  # shellcheck disable=SC2086
  exit ${ERR_ARCHIVE_NOT_SUPPORTED}
fi

echo "Flashing the image to ${DRIVE_TO_FLASH}..."
if is_linux; then
  sudo dd bs=4M if="${IMAGE_FILE_PATH}" of="${DRIVE_TO_FLASH}" conv=fdatasync status=progress
elif is_macos; then
  diskutil unmountDisk "${DRIVE_TO_FLASH}"
  sudo dd bs=4m if="${IMAGE_FILE_PATH}" of="${DRIVE_TO_FLASH}"
  sync
  sudo diskutil eject "${DRIVE_TO_FLASH}"
fi
