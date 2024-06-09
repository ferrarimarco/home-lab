#!/usr/bin/env sh

set -o errexit
set -o nounset

restic version

echo "Restic repository: ${RESTIC_REPOSITORY}"

echo "Checking if the ${RESTIC_REPOSITORY} Restic repository needs to be initalized."
if restic snapshots --verbose; then
  echo "The ${RESTIC_REPOSITORY} repository is already initialized."
else
  echo "Initializing the ${RESTIC_REPOSITORY} repository"
  restic init --verbose
fi

echo "Getting the list of Restic locks that are currently active."
restic list locks --no-lock --verbose

echo "Removing eventual stale Restic locks..."
restic unlock --verbose

echo "Getting the list of Restic locks that are currently active again."
restic list locks --no-lock --verbose

if [ "${RESTIC_ENABLE_BACKUP:-"false"}" = "true" ]; then
  echo "Backing up ${RESTIC_DIRECTORIES_TO_BACKUP}. Tags: ${RESTIC_BACKUP_TAGS}"
  # Use eval here because restic interprets quotes literally
  eval "restic backup --group-by host,tags --tag ${RESTIC_BACKUP_TAGS} --verbose ${RESTIC_DIRECTORIES_TO_BACKUP}"
fi

if [ "${RESTIC_ENABLE_PRUNE:-"false"}" = "true" ]; then
  echo "Pruning ${RESTIC_REPOSITORY}"
  # Use eval here because restic interprets quotes literally
  eval "restic forget --group-by host,tags --no-cache --prune --verbose ${RESTIC_FORGET_POLICY}"
fi

if [ "${RESTIC_ENABLE_PRUNE_UNTAGGED_SNAPSHOTS:-"false"}" = "true" ]; then
  echo "Pruning untagged snapshots"
  # As a safety measure, Restic doesn't remove snapshots if the keep policy results in an
  # empty set. That's why we keep the last snapshot, to remove manually
  # (see the RESTIC_SNAPSHOT_TO_PRUNE block below).

  # Use eval here because restic interprets quotes literally
  eval "restic forget --keep-last 1 --no-cache --prune --tag '' --verbose"
fi

if [ -n "${RESTIC_SNAPSHOT_TO_PRUNE:-""}" ]; then
  echo "Forgetting and pruning specific snapshot: ${RESTIC_SNAPSHOT_TO_PRUNE}"
  eval "restic forget --no-cache --prune --verbose ${RESTIC_SNAPSHOT_TO_PRUNE}"
fi

if [ "${RESTIC_ENABLE_REPOSITORY_CHECK:-"false"}" = "true" ]; then
  echo "Checking the integrity of ${RESTIC_REPOSITORY}"
  restic check --no-cache --verbose
fi

if [ "${RESTIC_ENABLE_REPOSITORY_CHECK_ALL_DATA:-"false"}" = "true" ]; then
  echo "Checking the integrity of ${RESTIC_REPOSITORY}"
  restic check \
    --no-cache \
    --read-data \
    --verbose
fi

echo "Get information about the ${RESTIC_REPOSITORY} repository"

# Default mode is restore-size: counts the size of the restored files
restic stats --no-cache

# raw-data mode: counts the size of the blobs in the repository, regardless of
# how many files reference them. This tells you how much restic has reduced all
# your original data down to (either for a single snapshot or across all your
# backups), and compared to the size given by the restore-size mode, can tell
# you how much deduplication is helping you.
restic stats --mode raw-data --no-cache
restic snapshots --no-cache
