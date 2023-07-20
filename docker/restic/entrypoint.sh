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

if [ "${RESTIC_ENABLE_BACKUP:-"false"}" = "true" ]; then
  echo "Backing up ${RESTIC_DIRECTORIES_TO_BACKUP}. Tags: ${RESTIC_BACKUP_TAGS}"
  # Use eval here because restic interprets quotes literally
  eval "restic backup --tag ${RESTIC_BACKUP_TAGS} --verbose ${RESTIC_DIRECTORIES_TO_BACKUP}"
fi

if [ "${RESTIC_ENABLE_PRUNE:-"false"}" = "true" ]; then
  echo "Pruning ${RESTIC_REPOSITORY}"
  # Use eval here because restic interprets quotes literally
  eval "restic forget --no-cache --prune --verbose ${RESTIC_FORGET_POLICY}"
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
  restic --no-cache --verbose check
fi

echo "Get information about the ${RESTIC_REPOSITORY} repository"
restic stats --no-cache
restic snapshots --no-cache
