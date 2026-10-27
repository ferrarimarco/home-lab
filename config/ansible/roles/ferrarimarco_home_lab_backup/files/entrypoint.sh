#!/usr/bin/env sh

set -o errexit
set -o nounset

restic version

echo "Restic repository: ${RESTIC_REPOSITORY}"

echo "Checking if the ${RESTIC_REPOSITORY} Restic repository is initialized."
# Lock-taking commands wait for a concurrent job (the nightly prune, the
# exporter's check) instead of failing on the lock.
restic_retry_lock="${RESTIC_RETRY_LOCK:-30m}"
if restic snapshots --retry-lock "${restic_retry_lock}" --verbose; then
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
      if [ -n "${RESTIC_REPOSITORY_CHECK_READ_DATA_CYCLE_DAYS:-""}" ]; then
        echo "restic_check_read_data_cycle_days{backup_job=\"${restic_backup_job}\"} ${RESTIC_REPOSITORY_CHECK_READ_DATA_CYCLE_DAYS}"
      fi
      if [ -n "${restic_restore_drill_files:-""}" ]; then
        echo "# HELP restic_restore_drill_files Files the latest restore drill restored and verified."
        echo "# TYPE restic_restore_drill_files gauge"
        echo "restic_restore_drill_files{backup_job=\"${restic_backup_job}\"} ${restic_restore_drill_files}"
      fi
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

# Restore mode: RESTIC_RESTORE_SNAPSHOT (an id or "latest") selects the
# snapshot, RESTIC_RESTORE_INCLUDE the path within it, RESTIC_RESTORE_TARGET
# the directory to restore under, and RESTIC_RESTORE_DRY_RUN (default true)
# only lists what would be restored. The space guard compares the listed file
# sizes with the free space of the target, with a 20 percent margin, so a
# restore never fills a filesystem. The monthly drill (RESTIC_RESTORE_DRILL)
# is this mode with the job's drill subtree and target, no dry run, a cleanup
# of the target in every case, and a step timestamp for the alerts.
if [ "${RESTIC_RESTORE_DRILL:-"false"}" = "true" ]; then
  RESTIC_RESTORE_SNAPSHOT="${RESTIC_RESTORE_SNAPSHOT:-latest}"
  RESTIC_RESTORE_INCLUDE="${RESTIC_RESTORE_INCLUDE:-${RESTIC_RESTORE_DRILL_INCLUDE}}"
  # The drill target is the scratch directory and nothing else: the cleanup
  # below empties it, so an externally supplied target is refused rather than
  # honoured.
  RESTIC_RESTORE_TARGET="${RESTIC_RESTORE_DRILL_TARGET}"
  RESTIC_RESTORE_DRY_RUN="false"
  case "${RESTIC_RESTORE_TARGET}" in
  "" | / | /etc* | /var/lib/restic/repository*)
    echo "Refusing to drill into ${RESTIC_RESTORE_TARGET}" >&2
    exit 1
    ;;
  esac
  # The cleanup below empties the target: refuse a target that holds the
  # repository or any directory of the backup set, wherever they live (the
  # pattern above only covers the container's repository mount point).
  for protected_path in ${RESTIC_REPOSITORY} ${RESTIC_DIRECTORIES_TO_BACKUP:-}; do
    case "${protected_path}" in
    "${RESTIC_RESTORE_TARGET}" | "${RESTIC_RESTORE_TARGET}"/*)
      echo "Refusing to drill into ${RESTIC_RESTORE_TARGET}: it holds ${protected_path}" >&2
      exit 1
      ;;
    esac
  done
  clean_drill_target() {
    echo "Cleaning the drill target ${RESTIC_RESTORE_TARGET}"
    find "${RESTIC_RESTORE_TARGET}" -mindepth 1 -delete
  }
  # Clean on exit and on a stop signal (docker stop sends TERM); the trap keeps
  # the exit status of a failed restore, so the unit still fails.
  trap clean_drill_target EXIT
  trap 'clean_drill_target; exit 143' TERM INT
  # Start from an empty target, so the strict count check applies even after
  # a drill that was killed before its cleanup
  mkdir -p "${RESTIC_RESTORE_TARGET}"
  clean_drill_target
fi

if [ -n "${RESTIC_RESTORE_SNAPSHOT:-""}" ]; then
  restore_dry_run="${RESTIC_RESTORE_DRY_RUN:-true}"
  echo "Restoring ${RESTIC_RESTORE_INCLUDE} from snapshot ${RESTIC_RESTORE_SNAPSHOT} under ${RESTIC_RESTORE_TARGET} (dry run: ${restore_dry_run})"
  restore_listing="$(restic ls --recursive --json --no-lock "${RESTIC_RESTORE_SNAPSHOT}" "${RESTIC_RESTORE_INCLUDE}")"
  restore_expected_files="$(printf '%s\n' "${restore_listing}" | grep -c '"type":"file"' || true)"
  restore_expected_bytes="$(printf '%s\n' "${restore_listing}" | grep '"type":"file"' | sed -n 's/.*"size":\([0-9]*\).*/\1/p' | awk '{ s += $1 } END { print s + 0 }')"
  echo "The snapshot holds ${restore_expected_files} files (${restore_expected_bytes} bytes) under ${RESTIC_RESTORE_INCLUDE}"
  if [ "${restore_expected_files}" -eq 0 ]; then
    # A stack may have only one of the two state trees; the restore playbook
    # allows the empty case, a manual restore of a wrong path must not pass.
    if [ "${RESTIC_RESTORE_ALLOW_EMPTY:-"false"}" = "true" ]; then
      echo "Nothing to restore: ${RESTIC_RESTORE_INCLUDE} holds no files in snapshot ${RESTIC_RESTORE_SNAPSHOT}; skipping"
      restore_skip="true"
    else
      echo "Nothing to restore: ${RESTIC_RESTORE_INCLUDE} holds no files in snapshot ${RESTIC_RESTORE_SNAPSHOT}" >&2
      exit 1
    fi
  fi
fi

if [ -n "${RESTIC_RESTORE_SNAPSHOT:-""}" ] && [ "${restore_skip:-"false"}" != "true" ]; then
  mkdir -p "${RESTIC_RESTORE_TARGET}"
  # Into an empty target (the drill, an inspection restore) the restored file
  # count must equal the listing; in place, files written since the snapshot
  # legitimately remain, so the count must only reach the listing and
  # restic's own verification covers the restored files.
  restore_in_place="false"
  if [ -e "${RESTIC_RESTORE_TARGET}${RESTIC_RESTORE_INCLUDE}" ]; then restore_in_place="true"; fi
  # Measure the free space where the files land: the deepest existing path
  # under target plus include, since an in-place restore (target /) writes
  # into a bind-mounted tree, not into the container's root filesystem.
  restore_space_path="${RESTIC_RESTORE_TARGET}${RESTIC_RESTORE_INCLUDE}"
  while [ ! -e "${restore_space_path}" ]; do restore_space_path="$(dirname "${restore_space_path}")"; done
  restore_available_bytes="$(df -Pk "${restore_space_path}" | awk 'NR == 2 { print $4 * 1024 }')"
  restore_needed_bytes="$((restore_expected_bytes + restore_expected_bytes / 5))"
  if [ "${restore_available_bytes}" -lt "${restore_needed_bytes}" ]; then
    echo "Refusing to restore: ${RESTIC_RESTORE_TARGET} has ${restore_available_bytes} bytes free, ${restore_needed_bytes} needed (restore size plus a 20 percent margin)" >&2
    exit 1
  fi
  if [ "${restore_dry_run}" = "true" ]; then
    restic restore "${RESTIC_RESTORE_SNAPSHOT}" --target "${RESTIC_RESTORE_TARGET}" --include "${RESTIC_RESTORE_INCLUDE}" --retry-lock "${restic_retry_lock}" --dry-run --verbose=2
  else
    restic restore "${RESTIC_RESTORE_SNAPSHOT}" --target "${RESTIC_RESTORE_TARGET}" --include "${RESTIC_RESTORE_INCLUDE}" --retry-lock "${restic_retry_lock}" --verify --verbose
    restore_restored_files="$(find "${RESTIC_RESTORE_TARGET}${RESTIC_RESTORE_INCLUDE}" -type f | wc -l)"
    echo "Restored ${restore_restored_files} files under ${RESTIC_RESTORE_TARGET}${RESTIC_RESTORE_INCLUDE}"
    if [ "${restore_in_place}" = "true" ] && [ "${restore_restored_files}" -lt "${restore_expected_files}" ]; then
      echo "Restore mismatch: ${restore_restored_files} files present in place, ${restore_expected_files} listed in the snapshot" >&2
      exit 1
    fi
    if [ "${restore_in_place}" != "true" ] && [ "${restore_restored_files}" -ne "${restore_expected_files}" ]; then
      echo "Restore mismatch: ${restore_restored_files} files restored, ${restore_expected_files} listed in the snapshot" >&2
      exit 1
    fi
    if [ "${RESTIC_RESTORE_DRILL:-"false"}" = "true" ]; then
      record_step restore-drill
      restic_restore_drill_files="${restore_restored_files}"
    fi
  fi
fi

if [ "${RESTIC_ENABLE_BACKUP:-"false"}" = "true" ]; then
  echo "Backing up ${RESTIC_DIRECTORIES_TO_BACKUP}. Tags: ${RESTIC_BACKUP_TAGS}"
  # Use eval here because restic interprets quotes literally
  eval "restic backup --group-by host,tags --tag ${RESTIC_BACKUP_TAGS} --retry-lock ${restic_retry_lock} --verbose ${RESTIC_DIRECTORIES_TO_BACKUP}"
  record_step backup
fi

if [ "${RESTIC_ENABLE_PRUNE:-"false"}" = "true" ]; then
  echo "Pruning ${RESTIC_REPOSITORY}"
  # Use eval here because restic interprets quotes literally
  eval "restic forget --group-by host,tags --no-cache --prune --retry-lock ${restic_retry_lock} --verbose ${RESTIC_FORGET_POLICY}"
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
  restic check --no-cache --retry-lock "${restic_retry_lock}" --verbose
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
  restic check --no-cache --read-data-subset="${read_data_group}/${read_data_cycle}" --retry-lock "${restic_retry_lock}" --verbose
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
