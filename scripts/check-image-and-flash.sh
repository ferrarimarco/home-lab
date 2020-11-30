#!/usr/bin/env sh

set -e

OS_IMAGE_ARCHIVE_PATH="$1"
if [ -z "${OS_IMAGE_ARCHIVE_PATH}" ]; then
  echo "Pass the OS image archive path as the first option. Terminating..."
  exit 1
fi

if ! [ -f "${OS_IMAGE_ARCHIVE_PATH}" ]; then
  echo "${OS_IMAGE_ARCHIVE_PATH} not found. Terminating..."
  exit 1
fi

DEVICE_TO_FLASH="$2"
if [ -z "${DEVICE_TO_FLASH}" ]; then
  echo "Pass the path to the device to flash as the second option. Terminating..."
  exit 1
fi

if ! [ -e "${DEVICE_TO_FLASH}" ]; then
  echo "${DEVICE_TO_FLASH} not found. Terminating..."
  exit 1
fi

OS_IMAGE_ARCHIVE_SUM_PATH="${OS_IMAGE_ARCHIVE_PATH}".sha256sum
if ! [ -f "${OS_IMAGE_ARCHIVE_SUM_PATH}" ]; then
  echo "${OS_IMAGE_ARCHIVE_SUM_PATH} not found. Terminating..."
  exit 1
fi

CURRENT_WORKING_DIRECTORY="$(pwd)"
echo "Current working directory: ${CURRENT_WORKING_DIRECTORY}"

cd "$(dirname "${OS_IMAGE_ARCHIVE_SUM_PATH}")" || exit 1

OS_IMAGE_FILE_PATH="$(basename "${OS_IMAGE_ARCHIVE_PATH}" .xz)"
echo "Deleting old image file..."
rm -f "${OS_IMAGE_FILE_PATH}"

echo "Checking hashes contained in ${OS_IMAGE_ARCHIVE_SUM_PATH}..."
sha256sum -c "${OS_IMAGE_ARCHIVE_SUM_PATH}"

echo "Unzipping the ${OS_IMAGE_ARCHIVE_PATH} image archive"
xz -vkd "${OS_IMAGE_ARCHIVE_PATH}"

echo "Erasing all contents on ${DEVICE_TO_FLASH}"
sudo dd bs=1m if=/dev/zero of="${DEVICE_TO_FLASH}" count=10
sudo sync

echo "Flashing ${OS_IMAGE_FILE_PATH} to ${DEVICE_TO_FLASH}..."
sudo dd bs=1m if="${OS_IMAGE_FILE_PATH}" of="${DEVICE_TO_FLASH}"
sudo sync

cd "${CURRENT_WORKING_DIRECTORY}" || exit 1
