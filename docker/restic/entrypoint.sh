#!/usr/bin/env sh

set -o errexit
set -o nounset

restic version

echo "Restic repository: ${RESTIC_REPOSITORY}"

echo "Checking if the ${RESTIC_REPOSITORY} Restic repository needs to be initalized."
if restic --verbose snapshots; then
  echo "The ${RESTIC_REPOSITORY} repository is already initialized."
else
  echo "Initializing the ${RESTIC_REPOSITORY} repository"
  restic --verbose init
fi

if [ "${RESTIC_ENABLE_BACKUP:-"false"}" = "true" ]; then
  echo "Backing up ${RESTIC_DIRECTORIES_TO_BACKUP}"
  # Use eval here because restic interprets quotes literally
  eval "restic --verbose backup ${RESTIC_DIRECTORIES_TO_BACKUP}"
fi

if [ "${RESTIC_ENABLE_PRUNE:-"false"}" = "true" ]; then
  echo "Pruning ${RESTIC_DIRECTORIES_TO_BACKUP}"
  # Use eval here because restic interprets quotes literally
  eval "restic --verbose forget --prune ${RESTIC_FORGET_POLICY}"
fi

if [ "${RESTIC_ENABLE_REPOSITORY_CHECK:-"false"}" = "true" ]; then
  echo "Checking the integrity of ${RESTIC_REPOSITORY}"
  restic --verbose check
fi

# Get some information about the repository
restic stats
restic snapshots