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

# The repository identity is read as soon as the repository is open: a job
# whose repository identity changes has been pointed at a different
# repository, which is never expected. The metrics are written at the end of
# the run (see write_textfile), so a run that fails midway leaves the previous
# values in place and the step timestamps stop advancing.
restic_backup_job="$(printf '%s' "${RESTIC_BACKUP_TAGS}" | tr -d '"')"
restic_repository_id="$(restic cat config --no-lock | sed -n 's/.*"id": *"\([0-9a-f]*\)".*/\1/p')"
echo "Repository identity: ${restic_repository_id}"

# Step timestamps persist in a state file next to the textfile, so a run that
# executes only some steps (initialization, a restore) keeps the others' last
# success visible.
restic_steps_file="${RESTIC_TEXTFILE_COLLECTOR_DIRECTORY:-/nonexistent}/restic-${restic_backup_job}.steps"
record_step() {
  # record_step <step> [<label>="<value>"]
  if [ -n "${RESTIC_TEXTFILE_COLLECTOR_DIRECTORY:-""}" ]; then
    {
      [ -f "${restic_steps_file}" ] && grep -v "^${1} " "${restic_steps_file}"
      echo "${1} $(date +%s) ${2:-}"
    } >"${restic_steps_file}.tmp" || true
    mv "${restic_steps_file}.tmp" "${restic_steps_file}"
  fi
}
write_textfile() {
  if [ -n "${RESTIC_TEXTFILE_COLLECTOR_DIRECTORY:-""}" ]; then
    restic_textfile="${RESTIC_TEXTFILE_COLLECTOR_DIRECTORY}/restic-${restic_backup_job}.prom"
    echo "Writing the job metrics to ${restic_textfile}"
    {
      echo "# HELP restic_repository_id Identity of the repository the restic job opened; written by the job."
      echo "# TYPE restic_repository_id gauge"
      echo "restic_repository_id{backup_job=\"${restic_backup_job}\",repository_id=\"${restic_repository_id}\"} 1"
      echo "# HELP restic_job_last_run_timestamp_seconds Unix time of the latest restic job run that completed."
      echo "# TYPE restic_job_last_run_timestamp_seconds gauge"
      echo "restic_job_last_run_timestamp_seconds{backup_job=\"${restic_backup_job}\"} $(date +%s)"
      echo "# HELP restic_check_read_data_cycle_days Nights over which the job reads every pack file of the repository once."
      echo "# TYPE restic_check_read_data_cycle_days gauge"
      echo "restic_check_read_data_cycle_days{backup_job=\"${restic_backup_job}\"} ${RESTIC_REPOSITORY_CHECK_READ_DATA_CYCLE_DAYS:-0}"
      if [ -f "${restic_steps_file}" ]; then
        echo "# HELP restic_job_step_last_success_timestamp_seconds Unix time of the latest successful run of each step of the restic job."
        echo "# TYPE restic_job_step_last_success_timestamp_seconds gauge"
        while read -r step_name step_time step_labels; do
          echo "restic_job_step_last_success_timestamp_seconds{backup_job=\"${restic_backup_job}\",step=\"${step_name}\"${step_labels:+,${step_labels}}} ${step_time}"
        done <"${restic_steps_file}"
      fi
    } >"${restic_textfile}.tmp"
    mv "${restic_textfile}.tmp" "${restic_textfile}"
  fi
}

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
  record_step backup
fi

if [ "${RESTIC_ENABLE_PRUNE:-"false"}" = "true" ]; then
  echo "Pruning ${RESTIC_REPOSITORY}"
  # Use eval here because restic interprets quotes literally
  eval "restic forget --group-by host,tags --no-cache --prune --verbose ${RESTIC_FORGET_POLICY}"
  record_step prune
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
  echo "Checking the structure of ${RESTIC_REPOSITORY}"
  restic check --no-cache --verbose
  record_step check
fi

# Read the pack files themselves, one group per night: restic assigns each
# pack to a fixed group by its identifier, so every pack is read once per
# cycle whatever gets added or repacked meanwhile, and a cycle of 1 reads the
# whole repository every night. The structural check above never reads them.
if [ "${RESTIC_REPOSITORY_CHECK_READ_DATA_CYCLE_DAYS:-0}" -gt 0 ]; then
  read_data_cycle="${RESTIC_REPOSITORY_CHECK_READ_DATA_CYCLE_DAYS}"
  read_data_group="$((($(date +%s) / 86400) % read_data_cycle + 1))"
  echo "Reading pack group ${read_data_group}/${read_data_cycle} of ${RESTIC_REPOSITORY}"
  restic check --no-cache --read-data-subset="${read_data_group}/${read_data_cycle}" --verbose
  record_step check-read-data "group=\"${read_data_group}/${read_data_cycle}\""
fi

write_textfile

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
