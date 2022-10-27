#!/usr/bin/env sh

set -o errexit
set -o nounset

# Doesn't follow symlinks, but it's likely expected for most users
SCRIPT_BASENAME="$(basename "${0}")"
SCRIPT_DIRECTORY_PATH="$(dirname "${0}")"

echo "This script (name: ${SCRIPT_BASENAME}, directory path: ${SCRIPT_DIRECTORY_PATH}) has been invoked with: ${0} $*"

# shellcheck source=/dev/null
. "${SCRIPT_DIRECTORY_PATH}/common.sh"

if ! is_container_runtime_available; then
  echo "Container engine not available. Running a non-containerized command"
  WORKING_DIRECTORY="$(pwd)"

  VIRTUAL_ENVIRONMENT_PATH="${WORKING_DIRECTORY}/.venv"
  PIP_REQUIREMENTS_FILE_PATH="${PIP_REQUIREMENTS_FILE_PATH:-"${WORKING_DIRECTORY}/docker/ansible/requirements.txt"}"
  create_and_activate_python_virtual_environment "${VIRTUAL_ENVIRONMENT_PATH}" "${PIP_REQUIREMENTS_FILE_PATH}"

  ANSIBLE_DIRECTORY="${WORKING_DIRECTORY}/docker/ansible/etc/ansible"
  ANSIBLE_ROLES_PATH="${ANSIBLE_ROLES_PATH:-"${ANSIBLE_DIRECTORY}/roles"}"
  export ANSIBLE_ROLES_PATH

  COMMAND_TO_RUN="${1}"
else
  echo "Not yet implemented"
  exit 1
fi

echo "Running command: ${COMMAND_TO_RUN}"
eval "${COMMAND_TO_RUN}"
