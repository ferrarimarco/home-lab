#!/usr/bin/env sh

set -o errexit
set -o nounset

# Doesn't follow symlinks, but it's likely expected for most users
SCRIPT_BASENAME="$(basename "${0}")"

echo "This script (${SCRIPT_BASENAME}) has been invoked with: $0 $*"

echo "Restic repository file: ${RESTIC_REPOSITORY_FILE}"
RESTIC_REPOSITORY_NAME="$(cat "${RESTIC_REPOSITORY_FILE}")"
echo "Restic repository: ${RESTIC_REPOSITORY_NAME}"

echo "Checking if the ${RESTIC_REPOSITORY_NAME} Restic repository needs to be initalized."

if restic snapshots; then
  echo "The ${RESTIC_REPOSITORY_NAME} repository is already initialized."
else
  echo "Initializing the ${RESTIC_REPOSITORY_NAME} repository"
  restic --verbose init
fi

if [ "${RESTIC_ENABLE_BACKUP}" = "true" ]; then
  echo "Backing up ${RESTIC_DIRECTORY_TO_BACKUP}"
  restic --verbose backup "${RESTIC_DIRECTORY_TO_BACKUP}"
fi

if [ "${RESTIC_ENABLE_REPOSITORY_CHECK}" = "true" ]; then
  echo "Checking the integrity of ${RESTIC_REPOSITORY_NAME}"
  restic --verbose check
fi
