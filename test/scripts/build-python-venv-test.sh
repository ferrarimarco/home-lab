#!/usr/bin/env sh

set -o errexit
set -o nounset

SCRIPT_BASENAME="$(basename "${0}")"
SCRIPT_DIRECTORY_PATH="$(dirname "${0}")"
SCRIPT_FULL_DIRECTORY_PATH="$(readlink -f "${SCRIPT_DIRECTORY_PATH}")"

echo "This script (name: ${SCRIPT_BASENAME}, directory path: ${SCRIPT_DIRECTORY_PATH}, full directory path: ${SCRIPT_FULL_DIRECTORY_PATH}) has been invoked with: ${0} $*"

PYTHON_VENV_PATH="$(mktemp -d)"
# shellcheck disable=SC2064 # Once the path is set, we don't expect it to change
trap "rm -fr '${PYTHON_VENV_PATH}'" EXIT

echo "PYTHON_VENV_PATH: ${PYTHON_VENV_PATH}"

SCRIPT_TO_TEST_PATH="${SCRIPT_FULL_DIRECTORY_PATH}/../../config/ansible/roles/ferrarimarco_home_lab_node/files/scripts/build-python-venv.sh"
SCRIPT_TO_TEST_PATH="$(readlink -f "${SCRIPT_TO_TEST_PATH}")"
echo "Script to test: ${SCRIPT_TO_TEST_PATH}"

PIP_REQUIREMENTS_FILE_PATH_TO_TEST="${SCRIPT_FULL_DIRECTORY_PATH}/../../config/ansible/roles/ferrarimarco_home_lab_node/files/config/monitoring-ont/requirements.txt"
PIP_REQUIREMENTS_FILE_PATH_TO_TEST="$(readlink -f "${PIP_REQUIREMENTS_FILE_PATH_TO_TEST}")"
echo "Pip requirements file path: ${PIP_REQUIREMENTS_FILE_PATH_TO_TEST}"

"${SCRIPT_TO_TEST_PATH}" \
  "${PYTHON_VENV_PATH}" \
  "${PIP_REQUIREMENTS_FILE_PATH_TO_TEST}"

echo "Running the script a second time to check if it doesn't rebuild the environment as expected"

"${SCRIPT_TO_TEST_PATH}" \
  "${PYTHON_VENV_PATH}" \
  "${PIP_REQUIREMENTS_FILE_PATH_TO_TEST}"
