#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail
shopt -s inherit_errexit

SCRIPT_FULL_DIRECTORY_PATH="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
REPOSITORY_SCRIPTS_DIRECTORY_PATH="$(readlink -f "${SCRIPT_FULL_DIRECTORY_PATH}/../../scripts")"

# shellcheck source=/dev/null
. "${REPOSITORY_SCRIPTS_DIRECTORY_PATH}/common.sh"

# Runs scripts/backup-secrets.sh against a fixture checkout and local restic
# repositories. The script finds its checkout from its own location, so the
# test runs a copy of it inside the fixture.

TEST_DIRECTORY_PATH="$(mktemp --directory)"
# shellcheck disable=SC2064 # Once the path is set, we don't expect it to change
trap "rm -fr '${TEST_DIRECTORY_PATH}'" EXIT

CHECKOUT_PATH="${TEST_DIRECTORY_PATH}/checkout"
SCRIPT_TO_TEST_PATH="${CHECKOUT_PATH}/scripts/backup-secrets.sh"
VAULT_PASSWORD_FILE_PATH="${CHECKOUT_PATH}/config/ansible/home_lab_vault_password_file"
VAULT_FILE_PATH="${CHECKOUT_PATH}/config/ansible/inventory/host_vars/host1/vault.yaml"
EXTRA_FILE_PATH="${TEST_DIRECTORY_PATH}/extra/id_test"
OUTPUT_FILE_PATH="${TEST_DIRECTORY_PATH}/output"
FIRST_REPOSITORY_PATH="${TEST_DIRECTORY_PATH}/repository-first"
SECOND_REPOSITORY_PATH="${TEST_DIRECTORY_PATH}/repository-second"
THIRD_REPOSITORY_PATH="${TEST_DIRECTORY_PATH}/repository-third"

export XDG_CACHE_HOME="${TEST_DIRECTORY_PATH}/cache"
export XDG_STATE_HOME="${TEST_DIRECTORY_PATH}/state"
export XDG_RUNTIME_DIR="${TEST_DIRECTORY_PATH}/runtime"
CONFIG_DIRECTORY_PATH="${CHECKOUT_PATH}/config/secrets-backup"
DESTINATIONS_FILE_PATH="${CONFIG_DIRECTORY_PATH}/destinations"
EXTRA_PATHS_FILE_PATH="${CONFIG_DIRECTORY_PATH}/extra-paths"
REPOSITORY_PASSWORD_FILE_PATH="${CONFIG_DIRECTORY_PATH}/password"

mkdir --parents \
  "${CHECKOUT_PATH}/.git" \
  "${CHECKOUT_PATH}/scripts" \
  "$(dirname "${VAULT_FILE_PATH}")" \
  "${CHECKOUT_PATH}/config/terraform/environments/backend/local/000-test/.terraform" \
  "$(dirname "${EXTRA_FILE_PATH}")" \
  "${CONFIG_DIRECTORY_PATH}" \
  "${XDG_RUNTIME_DIR}"
cp "${REPOSITORY_SCRIPTS_DIRECTORY_PATH}/common.sh" "${REPOSITORY_SCRIPTS_DIRECTORY_PATH}/backup-secrets.sh" "${CHECKOUT_PATH}/scripts/"

echo "vault password" >"${VAULT_PASSWORD_FILE_PATH}"
echo "vault file" >"${VAULT_FILE_PATH}"
echo "secret variables" >"${CHECKOUT_PATH}/config/terraform/environments/test-secrets.tfvars"
echo "state" >"${CHECKOUT_PATH}/config/terraform/environments/backend/local/000-test/terraform.tfstate"
echo "extra file" >"${EXTRA_FILE_PATH}"
# Two files that are not part of the set
echo "not a secret" >"$(dirname "${VAULT_FILE_PATH}")/main.yaml"
echo "state pointer" >"${CHECKOUT_PATH}/config/terraform/environments/backend/local/000-test/.terraform/terraform.tfstate"

echo "repository password" >"${REPOSITORY_PASSWORD_FILE_PATH}"
echo "${EXTRA_FILE_PATH}" >"${EXTRA_PATHS_FILE_PATH}"
cat >"${DESTINATIONS_FILE_PATH}" <<EOF
# A comment
first ${FIRST_REPOSITORY_PATH}
second ${SECOND_REPOSITORY_PATH}
EOF

# A restic that fails when an argument is the command that
# FAILING_RESTIC_COMMAND names, or on every call when it names "any"
REAL_RESTIC_PATH="$(command -v restic)"
export REAL_RESTIC_PATH
FAILING_RESTIC_DIRECTORY_PATH="${TEST_DIRECTORY_PATH}/failing-restic"
mkdir "${FAILING_RESTIC_DIRECTORY_PATH}"
cat >"${FAILING_RESTIC_DIRECTORY_PATH}/restic" <<'EOF'
#!/usr/bin/env bash
for argument in "$@"; do
  if [ "${FAILING_RESTIC_COMMAND}" = "any" ] || [ "${argument}" = "${FAILING_RESTIC_COMMAND}" ]; then
    exit 99
  fi
done
exec "${REAL_RESTIC_PATH}" "$@"
EOF
chmod +x "${FAILING_RESTIC_DIRECTORY_PATH}/restic"

fail() {
  echo "FAILED: ${1}"
  echo "Output of the last run:"
  cat "${OUTPUT_FILE_PATH}"
  exit 1
}

# Runs the script with the given arguments and checks its exit status
expect_status() {
  local expected_status="${1}"
  shift

  local actual_status=0
  "${SCRIPT_TO_TEST_PATH}" "$@" >"${OUTPUT_FILE_PATH}" 2>&1 || actual_status="${?}"
  if [ "${actual_status}" -ne "${expected_status}" ]; then
    fail "expected status ${expected_status}, got ${actual_status}, from: ${*:-"(no arguments)"}"
  fi

  local leftovers
  leftovers="$(find "${XDG_RUNTIME_DIR}" -mindepth 1)"
  if [ -n "${leftovers}" ]; then
    fail "a restore directory outlived the run: ${leftovers}"
  fi
}

# The same, with the restic that fails on the command given first
expect_status_with_failing_restic() {
  local failing_restic_command="${1}"
  shift

  FAILING_RESTIC_COMMAND="${failing_restic_command}" PATH="${FAILING_RESTIC_DIRECTORY_PATH}:${PATH}" expect_status "$@"
}

expect_output() {
  if ! grep --fixed-strings -- "${1}" "${OUTPUT_FILE_PATH}" >/dev/null; then
    fail "the output does not contain: ${1}"
  fi
}

# Reads the repositories without the script, whose run mode makes the next
# backup write a snapshot
restic_in_repository() {
  RESTIC_PASSWORD_FILE="${REPOSITORY_PASSWORD_FILE_PATH}" restic --repo "${1}" --quiet "${@:2}"
}

expect_snapshots() {
  local repository_path="${1}"
  local expected_snapshots="${2}"

  local snapshots
  snapshots="$(restic_in_repository "${repository_path}" snapshots --json)"
  local actual_snapshots
  actual_snapshots="$(jq 'length' <<<"${snapshots}")"
  if [ "${actual_snapshots}" -ne "${expected_snapshots}" ]; then
    fail "expected ${expected_snapshots} snapshots in ${repository_path}, got ${actual_snapshots}"
  fi
}

echo "Case: a repository that was not initialized is refused, not created"
expect_status "${ERR_SECRETS_BACKUP_FAILED}"
expect_output "Failed destinations: first second"

expect_status 0 run first init
expect_status 0 run second init

echo "Case: the first backup writes one snapshot per destination, with the set and nothing else"
expect_status 0
expect_snapshots "${FIRST_REPOSITORY_PATH}" 1
expect_snapshots "${SECOND_REPOSITORY_PATH}" 1
SNAPSHOT_NODES="$(restic_in_repository "${FIRST_REPOSITORY_PATH}" ls latest --json)"
SNAPSHOT_FILES="$(jq --raw-output 'select(.type == "file") | .path' <<<"${SNAPSHOT_NODES}" | LC_ALL=C sort)"
EXPECTED_SNAPSHOT_FILES="$(printf '%s\n' \
  "${VAULT_PASSWORD_FILE_PATH}" \
  "${VAULT_FILE_PATH}" \
  "${CHECKOUT_PATH}/config/terraform/environments/test-secrets.tfvars" \
  "${CHECKOUT_PATH}/config/terraform/environments/backend/local/000-test/terraform.tfstate" \
  "${DESTINATIONS_FILE_PATH}" \
  "${EXTRA_PATHS_FILE_PATH}" \
  "${EXTRA_FILE_PATH}" | LC_ALL=C sort)"
if [ "${SNAPSHOT_FILES}" != "${EXPECTED_SNAPSHOT_FILES}" ]; then
  fail "the snapshot holds: ${SNAPSHOT_FILES}"
fi

echo "Case: an unchanged set needs no restic at all"
expect_status_with_failing_restic any 0
expect_output "first: up to date"
expect_output "second: up to date"

echo "Case: a failing backup fails the run"
echo "vault file, edited" >"${VAULT_FILE_PATH}"
expect_status_with_failing_restic backup "${ERR_SECRETS_BACKUP_FAILED}"
expect_output "Failed destinations: first second"
expect_snapshots "${FIRST_REPOSITORY_PATH}" 1

echo "Case: verify reports a working copy that the latest snapshot does not hold"
expect_status "${ERR_SECRETS_BACKUP_FAILED}" verify
expect_output "first: the latest snapshot differs from the working copy: ${VAULT_FILE_PATH}"

echo "Case: a snapshot whose check or restore fails does not make its destination up to date"
expect_status_with_failing_restic check "${ERR_SECRETS_BACKUP_FAILED}"
expect_snapshots "${FIRST_REPOSITORY_PATH}" 2
expect_status_with_failing_restic restore "${ERR_SECRETS_BACKUP_FAILED}"
expect_snapshots "${FIRST_REPOSITORY_PATH}" 3
expect_status 0
expect_output "first: backing up"
expect_output "second: backing up"
expect_snapshots "${FIRST_REPOSITORY_PATH}" 4
expect_snapshots "${SECOND_REPOSITORY_PATH}" 4
expect_status 0 verify

echo "Case: a new file that matches a secret pattern gets a snapshot"
NEW_VAULT_FILE_PATH="${CHECKOUT_PATH}/config/ansible/inventory/host_vars/host2/vault.yaml"
mkdir "$(dirname "${NEW_VAULT_FILE_PATH}")"
echo "new vault file" >"${NEW_VAULT_FILE_PATH}"
expect_status 0
expect_snapshots "${FIRST_REPOSITORY_PATH}" 5
expect_status 0 verify

echo "Case: verify reports a snapshot that holds a file the working copy lost"
rm "${NEW_VAULT_FILE_PATH}"
expect_status "${ERR_SECRETS_BACKUP_FAILED}" verify
expect_output "first: the latest snapshot holds 8 files, the working copy 7"

echo "Case: a destination out of reach fails the run, and the other one is backed up"
mv "${SECOND_REPOSITORY_PATH}" "${SECOND_REPOSITORY_PATH}-away"
expect_status "${ERR_SECRETS_BACKUP_FAILED}"
expect_output "Failed destinations: second"
mv "${SECOND_REPOSITORY_PATH}-away" "${SECOND_REPOSITORY_PATH}"
expect_snapshots "${FIRST_REPOSITORY_PATH}" 6
expect_snapshots "${SECOND_REPOSITORY_PATH}" 5

echo "Case: the next run brings only the destination that failed up to date"
expect_status 0
expect_output "first: up to date"
expect_snapshots "${FIRST_REPOSITORY_PATH}" 6
expect_snapshots "${SECOND_REPOSITORY_PATH}" 6

echo "Case: the run mode makes the next backup of its destination write a snapshot"
expect_status 0 run first snapshots
expect_status 0
expect_output "first: backing up"
expect_output "second: up to date"
expect_snapshots "${FIRST_REPOSITORY_PATH}" 7

echo "Case: a name pointed at another repository gets a backup there"
restic_in_repository "${THIRD_REPOSITORY_PATH}" init
cat >"${DESTINATIONS_FILE_PATH}" <<EOF
first ${THIRD_REPOSITORY_PATH}
second ${SECOND_REPOSITORY_PATH}
EOF
expect_status 0
expect_output "first: backing up"
expect_snapshots "${THIRD_REPOSITORY_PATH}" 1

echo "Case: an extra path that is missing, a link, relative, or repeated fails the run before any backup"
echo "${TEST_DIRECTORY_PATH}/extra/missing" >>"${EXTRA_PATHS_FILE_PATH}"
expect_status "${ERR_SECRETS_BACKUP_FAILED}"
expect_output "Not a regular file: ${TEST_DIRECTORY_PATH}/extra/missing"
ln --symbolic "${EXTRA_FILE_PATH}" "${TEST_DIRECTORY_PATH}/extra/link"
echo "${TEST_DIRECTORY_PATH}/extra/link" >"${EXTRA_PATHS_FILE_PATH}"
expect_status "${ERR_SECRETS_BACKUP_FAILED}"
expect_output "Not a regular file: ${TEST_DIRECTORY_PATH}/extra/link"
echo "extra/id_test" >"${EXTRA_PATHS_FILE_PATH}"
expect_status "${ERR_SECRETS_BACKUP_FAILED}"
expect_output "Not an absolute path"
printf '%s\n' "${EXTRA_FILE_PATH}" "${EXTRA_FILE_PATH}" >"${EXTRA_PATHS_FILE_PATH}"
expect_status "${ERR_SECRETS_BACKUP_FAILED}"
expect_output "In the set more than once: ${EXTRA_FILE_PATH}"
echo "${EXTRA_FILE_PATH}" >"${EXTRA_PATHS_FILE_PATH}"
expect_snapshots "${THIRD_REPOSITORY_PATH}" 1

echo "Case: a destinations file that is malformed, empty, or missing fails the run"
cp "${DESTINATIONS_FILE_PATH}" "${DESTINATIONS_FILE_PATH}.saved"
echo "first" >"${DESTINATIONS_FILE_PATH}"
expect_status "${ERR_SECRETS_BACKUP_FAILED}"
expect_output "Expected a name"
echo "# Only a comment" >"${DESTINATIONS_FILE_PATH}"
expect_status "${ERR_SECRETS_BACKUP_FAILED}"
expect_output "No destination in"
rm "${DESTINATIONS_FILE_PATH}"
expect_status "${ERR_SECRETS_BACKUP_FAILED}"
expect_output "The destinations file does not exist"
mv "${DESTINATIONS_FILE_PATH}.saved" "${DESTINATIONS_FILE_PATH}"

echo "Case: a damaged pack file fails verify"
PACK_FILE_PATHS="$(find "${SECOND_REPOSITORY_PATH}/data" -type f | LC_ALL=C sort)"
PACK_FILE_PATH="${PACK_FILE_PATHS%%$'\n'*}"
chmod u+w "${PACK_FILE_PATH}"
printf 'damage' | dd of="${PACK_FILE_PATH}" bs=1 seek=16 conv=notrunc status=none
expect_status "${ERR_SECRETS_BACKUP_FAILED}" verify
expect_output "Failed destinations: second"

echo "Case: a Git worktree and a checkout without the vault password file are refused"
rmdir "${CHECKOUT_PATH}/.git"
echo "gitdir: elsewhere" >"${CHECKOUT_PATH}/.git"
expect_status "${ERR_SECRETS_BACKUP_FAILED}"
expect_output "Run from the main checkout"
rm "${CHECKOUT_PATH}/.git"
mkdir "${CHECKOUT_PATH}/.git"
rm "${VAULT_PASSWORD_FILE_PATH}"
expect_status "${ERR_SECRETS_BACKUP_FAILED}"
expect_output "Run from the main checkout"
expect_snapshots "${THIRD_REPOSITORY_PATH}" 1

echo "Case: an unknown destination and an unknown mode are usage errors"
expect_status "${ERR_ARGUMENT_EVAL}" run third snapshots
expect_status "${ERR_ARGUMENT_EVAL}" restore

echo "All the cases passed"
