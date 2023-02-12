#!/usr/bin/env sh

set -o errexit
set -o nounset

# Doesn't follow symlinks, but it's likely expected for most users
SCRIPT_BASENAME="$(basename "${0}")"

echo "This script (${SCRIPT_BASENAME}) has been invoked with: $0 $*"

echo "Restic repository file: ${RESTIC_REPOSITORY_FILE}"
RESTIC_REPOSITORY_NAME="$(cat ${RESTIC_REPOSITORY_FILE})"
echo "Restic repository: ${RESTIC_REPOSITORY_NAME}"

echo "Checking if the ${RESTIC_REPOSITORY_NAME} Restic repository needs to be initalized."

if restic snapshots; then
  echo "The ${RESTIC_REPOSITORY_NAME} repository is already initialized."
else
  echo "Initializing the ${RESTIC_REPOSITORY_NAME} repository"
  restic init
fi
