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
PIP_REQUIREMENTS_FILE_PATH="${PIP_REQUIREMENTS_FILE_PATH:-"$(pwd)/docker/ansible/requirements.txt"}"

(
  create_and_activate_python_virtual_environment "${VIRTUAL_ENVIRONMENT_PATH}" "${PIP_REQUIREMENTS_FILE_PATH}"
  PY_COLORS="1"
  export PY_COLORS
  ANSIBLE_FORCE_COLOR="1"
  export ANSIBLE_FORCE_COLOR
  MOLECULE_DISTRO="${MOLECULE_DISTRO:-"ubuntu:20.04"}"
  export MOLECULE_DISTRO
  cd "${ANSIBLE_ROLE_PATH}"
  molecule test
)
