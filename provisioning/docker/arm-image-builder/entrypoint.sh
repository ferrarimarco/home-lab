#!/usr/bin/env bash

set -o errtrace
set -o nounset
set -o pipefail
set -o errexit

OS_IMAGE_BASE_URL="$1"
OS_IMAGE_BASE_NAME="$2"

OS_IMAGE_IMAGE_FILE_NAME="${OS_IMAGE_BASE_NAME}.img"
OS_IMAGE_IMAGE_ARCHIVE_NAME="${OS_IMAGE_IMAGE_FILE_NAME}.xz"
OS_IMAGE_CHECKSUM_FILE_NAME="${OS_IMAGE_IMAGE_ARCHIVE_NAME}.sha256sum"
OS_IMAGE_IMAGE_FILE_URL="${OS_IMAGE_BASE_URL}"/"${OS_IMAGE_IMAGE_ARCHIVE_NAME}"

echo "Downloading ${OS_IMAGE_IMAGE_FILE_URL}..."
wget --quiet "$OS_IMAGE_IMAGE_FILE_URL"

echo "Verifying checksums..."
sha256sum --ignore-missing "${OS_IMAGE_CHECKSUM_FILE_NAME}"

echo "Extracting ${OS_IMAGE_ARCHIVE_NAME}"
tar xf "${OS_IMAGE_ARCHIVE_NAME}"

echo "Gathering information about ${OS_IMAGE_IMAGE_FILE_NAME}..."
fdisk -lu "${OS_IMAGE_IMAGE_FILE_NAME}"
parted "${OS_IMAGE_IMAGE_FILE_NAME}" unit s print

dev="$(losetup --show -f -P "${OS_IMAGE_IMAGE_FILE_NAME}")"
echo "Device: $dev"

for part in "${dev}"*; do
    if [[ "$part" = "${dev}p"* ]]; then
        part="${dev}"
    fi
    echo "Partition: "
    dst="/mnt/$(basename "$part")"
    echo "Mounting $part on $dst"
    mkdir -p "$dst"
    mount -o "discard" "$part" "$dst"
done

echo "Registering qemu-*-static for all supported processors except the current one..."
bash /register --reset -p yes >/dev/null 2>&1
