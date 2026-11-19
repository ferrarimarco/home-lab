#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail
shopt -s inherit_errexit

# shellcheck source=/dev/null
. "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/common.sh"

# Backs up the gitignored secret files of the checkout, plus the files a
# gitignored list names, to one restic repository per destination, and proves
# each backup by restoring it and comparing it with the working copy.

# Ignored by Git, as the secret files are. The two lists are part of the set,
# so that a restore brings them back; the password cannot be.
SECRETS_BACKUP_CONFIG_DIRECTORY_PATH="${REPOSITORY_ROOT_PATH}/config/secrets-backup"
# One destination per line: a name, then the restic repository
SECRETS_BACKUP_DESTINATIONS_FILE_PATH="${SECRETS_BACKUP_CONFIG_DIRECTORY_PATH}/destinations"
# Optional. One absolute file path per line, for secrets outside the checkout
SECRETS_BACKUP_EXTRA_PATHS_FILE_PATH="${SECRETS_BACKUP_CONFIG_DIRECTORY_PATH}/extra-paths"
export RESTIC_PASSWORD_FILE="${SECRETS_BACKUP_CONFIG_DIRECTORY_PATH}/password"

# Holds, for each destination, a digest of the set and of the repository, written
# once a snapshot of that set is verified there, so that an unchanged set costs
# no repository access
SECRETS_BACKUP_STATE_DIRECTORY_PATH="${XDG_STATE_HOME:-"${HOME}/.local/state"}/home-lab-secrets-backup"

# A checkout that lacks this file, such as a fresh clone, has no set to back up
SECRETS_BACKUP_SENTINEL_FILE_PATH="${REPOSITORY_ROOT_PATH}/config/ansible/home_lab_vault_password_file"

declare -a SECRET_FILE_PATHS=()
declare -a DESTINATION_NAMES=()
declare -A DESTINATION_REPOSITORIES=()
SECRETS_SET_DIGEST=

# Set from mktemp only: the cleanup deletes what this variable names
RESTORE_DIRECTORY_PATH=

remove_restore_directory() {
  if [ -n "${RESTORE_DIRECTORY_PATH}" ]; then
    rm -rf -- "${RESTORE_DIRECTORY_PATH}"
    RESTORE_DIRECTORY_PATH=
  fi
}
trap remove_restore_directory EXIT

load_secret_file_paths() {
  # A Git worktree has a .git file, not a directory, and holds at most the links
  # to the vault files that a playbook run needs: a snapshot taken there would
  # lack the rest of the set
  if [ ! -d "${REPOSITORY_ROOT_PATH}/.git" ] || [ ! -f "${SECRETS_BACKUP_SENTINEL_FILE_PATH}" ]; then
    echo "Run from the main checkout, with its secret files in place: ${REPOSITORY_ROOT_PATH} is a Git worktree, or ${SECRETS_BACKUP_SENTINEL_FILE_PATH} does not exist."
    exit "${ERR_SECRETS_BACKUP_FAILED}"
  fi

  local found_paths
  # The names are the ones .gitignore lists as secrets, except the developer
  # token, which is reissued instead of restored. .terraform directories hold a
  # pointer to the state, not the state.
  found_paths="$(find "${REPOSITORY_ROOT_PATH}/config" \
    -name ".terraform" -prune -o \
    \( -type f -o -type l \) \( \
    -name "home_lab_vault_password_file" \
    -o -name "vault.y*ml" \
    -o -name "secrets.y*ml" \
    -o -name "secret.yaml" \
    -o -name "*-secrets.tfvars" \
    -o -name "*-secrets.tfvars.json" \
    -o -name "terraform.tfstate*" \
    -o -name "home-lab-bootstrap-ssh" \
    \) -print | LC_ALL=C sort)"
  readarray -t SECRET_FILE_PATHS <<<"${found_paths}"
  SECRET_FILE_PATHS+=("${SECRETS_BACKUP_DESTINATIONS_FILE_PATH}")

  if [ -f "${SECRETS_BACKUP_EXTRA_PATHS_FILE_PATH}" ]; then
    SECRET_FILE_PATHS+=("${SECRETS_BACKUP_EXTRA_PATHS_FILE_PATH}")

    local extra_path
    while IFS= read -r extra_path || [ -n "${extra_path}" ]; do
      if [ -z "${extra_path}" ] || [[ ${extra_path} == "#"* ]]; then
        continue
      fi
      if [[ ${extra_path} != /* ]]; then
        echo "Not an absolute path, in ${SECRETS_BACKUP_EXTRA_PATHS_FILE_PATH}: ${extra_path}"
        exit "${ERR_SECRETS_BACKUP_FAILED}"
      fi
      SECRET_FILE_PATHS+=("${extra_path}")
    done <"${SECRETS_BACKUP_EXTRA_PATHS_FILE_PATH}"
  fi

  local secret_file_path
  for secret_file_path in "${SECRET_FILE_PATHS[@]}"; do
    # restic reports success when it skips a path that does not exist, and when
    # it stores a symbolic link in place of the file the link names
    if [ ! -f "${secret_file_path}" ] || [ -L "${secret_file_path}" ]; then
      echo "Not a regular file: ${secret_file_path}"
      exit "${ERR_SECRETS_BACKUP_FAILED}"
    fi
  done

  local sorted_paths
  sorted_paths="$(printf '%s\n' "${SECRET_FILE_PATHS[@]}" | LC_ALL=C sort)"
  local repeated_paths
  repeated_paths="$(uniq --repeated <<<"${sorted_paths}")"
  if [ -n "${repeated_paths}" ]; then
    echo "In the set more than once: ${repeated_paths}"
    exit "${ERR_SECRETS_BACKUP_FAILED}"
  fi

  local file_digests
  file_digests="$(sha256sum -- "${SECRET_FILE_PATHS[@]}")"
  SECRETS_SET_DIGEST="$(sha256sum <<<"${file_digests}")"
  SECRETS_SET_DIGEST="${SECRETS_SET_DIGEST%% *}"
}

load_destinations() {
  if [ ! -f "${SECRETS_BACKUP_DESTINATIONS_FILE_PATH}" ]; then
    echo "The destinations file does not exist: ${SECRETS_BACKUP_DESTINATIONS_FILE_PATH}"
    exit "${ERR_SECRETS_BACKUP_FAILED}"
  fi

  local name
  local repository
  while read -r name repository || [ -n "${name}" ]; do
    if [ -z "${name}" ] || [[ ${name} == "#"* ]]; then
      continue
    fi
    if [[ ! ${name} =~ ^[a-z0-9-]+$ ]] || [ -z "${repository}" ]; then
      echo "Expected a name (lowercase letters, digits, hyphens) and a restic repository, in ${SECRETS_BACKUP_DESTINATIONS_FILE_PATH}: ${name}"
      exit "${ERR_SECRETS_BACKUP_FAILED}"
    fi
    DESTINATION_NAMES+=("${name}")
    DESTINATION_REPOSITORIES["${name}"]="${repository}"
  done <"${SECRETS_BACKUP_DESTINATIONS_FILE_PATH}"

  if [ "${#DESTINATION_NAMES[@]}" -eq 0 ]; then
    echo "No destination in ${SECRETS_BACKUP_DESTINATIONS_FILE_PATH}"
    exit "${ERR_SECRETS_BACKUP_FAILED}"
  fi
}

check_restic_is_available() {
  if ! is_command_available "restic"; then
    echo "restic is not available. Run inside the operations Nix development shell."
    exit "${ERR_MISSING_RUNTIME_DEPENDENCY}"
  fi
}

destination_digest_file_path() {
  echo "${SECRETS_BACKUP_STATE_DIRECTORY_PATH}/${1}.sha256"
}

# Covers the repository as well as the set, so that a name pointed at another
# repository gets a backup
destination_digest() {
  local digest
  digest="$(sha256sum <<<"${SECRETS_SET_DIGEST} ${DESTINATION_REPOSITORIES["${1}"]}")" || return
  echo "${digest%% *}"
}

is_destination_up_to_date() {
  local digest_file_path
  digest_file_path="$(destination_digest_file_path "${1}")"
  [ -f "${digest_file_path}" ] && [ "$(<"${digest_file_path}")" = "$(destination_digest "${1}")" ]
}

# The callers test the status of the two functions below, which turns errexit
# off inside them: every step returns its own failure.

# Reads every pack of the repository, restores the latest snapshot, and compares
# it with the working copy, file by file.
verify_destination() {
  local name="${1}"
  local repository="${DESTINATION_REPOSITORIES["${name}"]}"

  echo "${name}: verifying"
  restic --repo "${repository}" check --read-data || return

  RESTORE_DIRECTORY_PATH="$(mktemp --directory --tmpdir="${XDG_RUNTIME_DIR:-"${TMPDIR:-/tmp}"}" home-lab-secrets-restore.XXXXXXXXXX)" || return
  restic --repo "${repository}" restore latest --target "${RESTORE_DIRECTORY_PATH}" --verify || return

  local differences=0
  local secret_file_path
  for secret_file_path in "${SECRET_FILE_PATHS[@]}"; do
    if ! cmp --silent "${RESTORE_DIRECTORY_PATH}${secret_file_path}" "${secret_file_path}"; then
      echo "${name}: the latest snapshot differs from the working copy: ${secret_file_path}"
      differences=$((differences + 1))
    fi
  done

  local restored_files
  restored_files="$(find "${RESTORE_DIRECTORY_PATH}" -type f -printf '.')" || return
  if [ "${#restored_files}" -ne "${#SECRET_FILE_PATHS[@]}" ]; then
    echo "${name}: the latest snapshot holds ${#restored_files} files, the working copy ${#SECRET_FILE_PATHS[@]}"
    differences=$((differences + 1))
  fi

  remove_restore_directory
  [ "${differences}" -eq 0 ]
}

backup_destination() {
  local name="${1}"

  echo "${name}: backing up"
  restic --repo "${DESTINATION_REPOSITORIES["${name}"]}" backup "${SECRET_FILE_PATHS[@]}" || return
  verify_destination "${name}" || return

  mkdir --parents "${SECRETS_BACKUP_STATE_DIRECTORY_PATH}" || return
  destination_digest "${name}" >"$(destination_digest_file_path "${name}")"
}

# Runs the given function for each given destination and fails after the last
# one, so that a destination out of reach does not keep the others behind.
run_for_destinations() {
  local destination_function="${1}"
  shift

  local -a failed_destination_names=()
  local name
  for name in "$@"; do
    if ! "${destination_function}" "${name}"; then
      remove_restore_directory
      failed_destination_names+=("${name}")
    fi
  done

  if [ "${#failed_destination_names[@]}" -gt 0 ]; then
    echo "Failed destinations: ${failed_destination_names[*]}"
    exit "${ERR_SECRETS_BACKUP_FAILED}"
  fi
}

MODE="${1:-"backup"}"

case "${MODE}" in
"backup")
  load_destinations
  load_secret_file_paths

  declare -a PENDING_DESTINATION_NAMES=()
  for destination_name in "${DESTINATION_NAMES[@]}"; do
    if is_destination_up_to_date "${destination_name}"; then
      echo "${destination_name}: up to date"
    else
      PENDING_DESTINATION_NAMES+=("${destination_name}")
    fi
  done

  if [ "${#PENDING_DESTINATION_NAMES[@]}" -gt 0 ]; then
    check_restic_is_available
    run_for_destinations backup_destination "${PENDING_DESTINATION_NAMES[@]}"
  fi
  ;;
"verify")
  load_destinations
  load_secret_file_paths
  check_restic_is_available
  run_for_destinations verify_destination "${DESTINATION_NAMES[@]}"
  ;;
"run")
  load_destinations
  check_restic_is_available
  if [ -z "${2:-}" ] || [ -z "${DESTINATION_REPOSITORIES["${2}"]:-}" ]; then
    echo "Usage: ${0} run <destination> <restic arguments>. Destinations: ${DESTINATION_NAMES[*]}"
    exit "${ERR_ARGUMENT_EVAL}"
  fi
  # The arguments may remove snapshots or create the repository anew, so the
  # next backup of this destination writes and verifies a snapshot again
  rm --force -- "$(destination_digest_file_path "${2}")"
  restic --repo "${DESTINATION_REPOSITORIES["${2}"]}" "${@:3}"
  ;;
*)
  echo "Usage: ${0} [backup | verify | run <destination> <restic arguments>]"
  exit "${ERR_ARGUMENT_EVAL}"
  ;;
esac
