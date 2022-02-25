#!/usr/bin/env sh

set -o errexit
set -o nounset

# Doesn't follow symlinks, but it's likely expected for most users
SCRIPT_BASENAME="$(basename "${0}")"
SCRIPT_DIRECTORY_PATH="$(dirname "${0}")"

echo "This script (name: ${SCRIPT_BASENAME}, directory path: ${SCRIPT_DIRECTORY_PATH}) has been invoked with: ${0} $*"

# shellcheck source=/dev/null
. "${SCRIPT_DIRECTORY_PATH}/common.sh"

WORKING_DIRECTORY="$(pwd)"
VIRTUAL_ENVIRONMENT_PATH="${WORKING_DIRECTORY}/.venv"

ANSIBLE_ROLE_PATH="${1}"
MOLECULE_DISTRO="${2}"
PIP_REQUIREMENTS_FILE_PATH="${PIP_REQUIREMENTS_FILE_PATH:-"$(pwd)/docker/ansible/requirements.txt"}"

(
  create_and_activate_python_virtual_environment "${VIRTUAL_ENVIRONMENT_PATH}" "${PIP_REQUIREMENTS_FILE_PATH}"

  echo "Running ansible-lint to lint ${ANSIBLE_ROLE_PATH}"
  ANSIBLE_ROLES_PATH="$(dirname "${ANSIBLE_ROLE_PATH}")"
  export ANSIBLE_ROLES_PATH
  echo "ANSIBLE_ROLES_PATH: ${ANSIBLE_ROLES_PATH}"
  ansible-lint -vv "${ANSIBLE_ROLE_PATH}"
  unset ANSIBLE_ROLES_PATH

  PY_COLORS="1"
  export PY_COLORS
  ANSIBLE_FORCE_COLOR="1"
  export ANSIBLE_FORCE_COLOR
  echo "Testing the ${ANSIBLE_ROLE_PATH} role against ${MOLECULE_DISTRO}"
  export MOLECULE_DISTRO
  cd "${ANSIBLE_ROLE_PATH}"
  molecule --debug test
)

unset ANSIBLE_ROLE_PATH
unset MOLECULE_DISTRO
unset PIP_REQUIREMENTS_FILE_PATH
