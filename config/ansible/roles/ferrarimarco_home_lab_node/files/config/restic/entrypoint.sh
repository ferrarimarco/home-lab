#!/usr/bin/env sh

set -o errexit
set -o nounset

restic version

echo "Restic repository: ${RESTIC_REPOSITORY}"

echo "Checking if the ${RESTIC_REPOSITORY} Restic repository is initialized."
if restic snapshots --verbose; then
  echo "The ${RESTIC_REPOSITORY} repository is already initialized."
elif [ "${RESTIC_ALLOW_INIT:-"false"}" = "true" ]; then
  echo "Initializing the ${RESTIC_REPOSITORY} repository"
  restic init --verbose
else
  # A missing repository is never initialized implicitly: when the mount
  # backing the repository path is gone, the path is a bare directory on the
  # host's root disk, and an implicit init would back the host up to itself
  # with a successful exit status (raspberrypi2, 2026-10-10). Provisioning
  # initializes repositories through a dedicated Ansible task that sets
  # RESTIC_ALLOW_INIT after checking the path's filesystem.
  echo "No repository at ${RESTIC_REPOSITORY} and RESTIC_ALLOW_INIT is not set: refusing to initialize." >&2
  exit 1
fi

if [ -n "${RESTIC_TEXTFILE_COLLECTOR_DIRECTORY:-""}" ]; then
  # Expose the repository identity to the node exporter textfile collector: a
  # job whose repository identity changes has been pointed at a different
  # repository, which is never expected.
  restic_backup_job="$(printf '%s' "${RESTIC_BACKUP_TAGS}" | tr -d '"')"
  restic_repository_id="$(restic cat config --no-lock | sed -n 's/.*"id": *"\([0-9a-f]*\)".*/\1/p')"
  restic_textfile="${RESTIC_TEXTFILE_COLLECTOR_DIRECTORY}/restic-${restic_backup_job}.prom"
  echo "Writing the repository identity (${restic_repository_id}) to ${restic_textfile}"
  {
    echo "# HELP restic_repository_id Identity of the repository the restic job opened; written by the job."
    echo "# TYPE restic_repository_id gauge"
    echo "restic_repository_id{backup_job=\"${restic_backup_job}\",repository_id=\"${restic_repository_id}\"} 1"
    echo "# HELP restic_job_last_run_timestamp_seconds Unix time of the latest restic job run that opened the repository."
    echo "# TYPE restic_job_last_run_timestamp_seconds gauge"
    echo "restic_job_last_run_timestamp_seconds{backup_job=\"${restic_backup_job}\"} $(date +%s)"
  } >"${restic_textfile}.tmp"
  mv "${restic_textfile}.tmp" "${restic_textfile}"
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
