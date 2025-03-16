#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

# Doesn't follow symlinks, but it's likely expected for most users
SCRIPT_BASENAME="$(basename "${0}")"
SCRIPT_DIRECTORY_PATH="$(dirname "${0}")"

echo "This script (name: ${SCRIPT_BASENAME}, directory path: ${SCRIPT_DIRECTORY_PATH}) has been invoked with: ${0} $*"

# shellcheck source=/dev/null
. "${SCRIPT_DIRECTORY_PATH}/common.sh"

WORKING_DIRECTORY="$(pwd)"

VIRTUAL_ENVIRONMENT_PATH="${WORKING_DIRECTORY}/.venv-pre-commit"
PIP_REQUIREMENTS_FILE_PATH="${PIP_REQUIREMENTS_FILE_PATH:-"${WORKING_DIRECTORY}/config/pre-commit/requirements.txt"}"
create_and_activate_python_virtual_environment "${VIRTUAL_ENVIRONMENT_PATH}" "${PIP_REQUIREMENTS_FILE_PATH}"

COMMAND_TO_RUN="${1:-"pre-commit run --all-files --config config/pre-commit/.pre-commit-config.yaml --verbose"}"

echo "Running command: ${COMMAND_TO_RUN}"
eval "${COMMAND_TO_RUN}"
