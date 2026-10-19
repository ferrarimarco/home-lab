#!/usr/bin/env sh

# Validate the Prometheus alerting rules and run their promtool unit tests with
# the Prometheus release the monitoring backend runs, read from the single pin
# the dependency updates helper Dockerfile holds.

set -o errexit
set -o nounset

SCRIPT_BASENAME="$(basename "${0}")"
SCRIPT_DIRECTORY_PATH="$(dirname "${0}")"
SCRIPT_FULL_DIRECTORY_PATH="$(readlink -f "${SCRIPT_DIRECTORY_PATH}")"

echo "This script (name: ${SCRIPT_BASENAME}, directory path: ${SCRIPT_DIRECTORY_PATH}, full directory path: ${SCRIPT_FULL_DIRECTORY_PATH}) has been invoked with: ${0} $*"

REPOSITORY_ROOT_PATH="$(readlink -f "${SCRIPT_FULL_DIRECTORY_PATH}/../..")"
echo "Repository root path: ${REPOSITORY_ROOT_PATH}"

NODE_ROLE_FILES_PATH="config/ansible/roles/ferrarimarco_home_lab_node/files/config"
DEPENDENCY_UPDATES_HELPER_DOCKERFILE_PATH="${REPOSITORY_ROOT_PATH}/${NODE_ROLE_FILES_PATH}/dependency-updates-helper/Dockerfile"
RULES_FILE_PATH="${NODE_ROLE_FILES_PATH}/monitoring-backend/prometheus-alerting-rules.yaml"
TESTS_DIRECTORY_PATH="test/prometheus-rules"

# The Ansible role reads the same FROM line (image reference in the second
# field, stage name in the fourth) to render the compose files.
PROMETHEUS_CONTAINER_IMAGE_ID="$(awk '$1 == "FROM" && $4 == "prometheus" { print $2 }' "${DEPENDENCY_UPDATES_HELPER_DOCKERFILE_PATH}")"
if [ -z "${PROMETHEUS_CONTAINER_IMAGE_ID}" ]; then
  echo "Cannot find the prometheus stage in ${DEPENDENCY_UPDATES_HELPER_DOCKERFILE_PATH}" >&2
  exit 1
fi
echo "Prometheus container image: ${PROMETHEUS_CONTAINER_IMAGE_ID}"

cd "${REPOSITORY_ROOT_PATH}"
TEST_FILE_PATHS="$(find "${TESTS_DIRECTORY_PATH}" -name '*.yaml' -type f | sort)"

COVERAGE_WORK_PATH="$(mktemp -d)"
# shellcheck disable=SC2064 # Once the path is set, we don't expect it to change
trap "rm -fr '${COVERAGE_WORK_PATH}'" EXIT

echo "Checking that every rule has a unit test with a non-firing case"
# Rules are written as "- alert: Name"; a test case names its rule as
# "alertname: Name" and a non-firing case follows it with "exp_alerts: []".
awk '$1 == "-" && $2 == "alert:" { print $3 }' "${RULES_FILE_PATH}" | sort -u >"${COVERAGE_WORK_PATH}/rules"
# shellcheck disable=SC2086 # The test file names contain no whitespace
cat ${TEST_FILE_PATHS} >"${COVERAGE_WORK_PATH}/tests.yaml"
awk '$1 == "alertname:" { print $2 }' "${COVERAGE_WORK_PATH}/tests.yaml" | sort -u >"${COVERAGE_WORK_PATH}/tested"
awk '$1 == "alertname:" { name = $2; next } $1 == "exp_alerts:" && $2 == "[]" && name != "" { print name } { name = "" }' "${COVERAGE_WORK_PATH}/tests.yaml" | sort -u >"${COVERAGE_WORK_PATH}/non-firing"

COVERAGE_ERRORS=0
UNTESTED_RULES="$(comm -23 "${COVERAGE_WORK_PATH}/rules" "${COVERAGE_WORK_PATH}/tested")"
if [ -n "${UNTESTED_RULES}" ]; then
  echo "Rules without a unit test (add a case to ${TESTS_DIRECTORY_PATH}):" >&2
  echo "${UNTESTED_RULES}" >&2
  COVERAGE_ERRORS=1
fi
ORPHAN_TESTS="$(comm -13 "${COVERAGE_WORK_PATH}/rules" "${COVERAGE_WORK_PATH}/tested")"
if [ -n "${ORPHAN_TESTS}" ]; then
  echo "Tests naming a rule that ${RULES_FILE_PATH} does not define:" >&2
  echo "${ORPHAN_TESTS}" >&2
  COVERAGE_ERRORS=1
fi
RULES_WITHOUT_NON_FIRING_CASE="$(comm -23 "${COVERAGE_WORK_PATH}/rules" "${COVERAGE_WORK_PATH}/non-firing")"
if [ -n "${RULES_WITHOUT_NON_FIRING_CASE}" ]; then
  echo "Rules without a non-firing case (an alertname followed by exp_alerts: []):" >&2
  echo "${RULES_WITHOUT_NON_FIRING_CASE}" >&2
  COVERAGE_ERRORS=1
fi
if [ "${COVERAGE_ERRORS}" -ne 0 ]; then
  exit 1
fi
echo "All $(wc -l <"${COVERAGE_WORK_PATH}/rules" | tr -d ' ') rules have a unit test with a non-firing case"

# promtool resolves the rule_files paths of a test file relative to the test
# file's directory, so the repository is mounted whole to keep them valid.
CONTAINER_WORKSPACE_PATH="/workspace"

run_promtool() {
  docker run \
    --entrypoint promtool \
    --rm \
    --volume "${REPOSITORY_ROOT_PATH}:${CONTAINER_WORKSPACE_PATH}:ro" \
    --workdir "${CONTAINER_WORKSPACE_PATH}" \
    "${PROMETHEUS_CONTAINER_IMAGE_ID}" \
    "$@"
}

echo "Checking the rules file: ${RULES_FILE_PATH}"
run_promtool check rules "${RULES_FILE_PATH}"

echo "Running the rule unit tests in: ${TESTS_DIRECTORY_PATH}"
# Each test file is a positional argument, relative to the mounted repository
# root; promtool runs every file, reports each failing one, and exits
# non-zero when any failed.
# shellcheck disable=SC2086 # The test file names contain no whitespace
run_promtool test rules ${TEST_FILE_PATHS}
