#!/usr/bin/env sh

set -o errexit
set -o nounset

# Doesn't follow symlinks, but it's likely expected for most users
SCRIPT_BASENAME="$(basename "${0}")"
SCRIPT_DIRECTORY_PATH="$(dirname "${0}")"
CURRENT_WORKING_DIRECTORY="$(pwd)"

echo "This script (name: ${SCRIPT_BASENAME}, directory path: ${SCRIPT_DIRECTORY_PATH}) has been invoked with: ${0} $*"
echo "Current working directory: ${CURRENT_WORKING_DIRECTORY}"

# shellcheck source=/dev/null
. "${SCRIPT_DIRECTORY_PATH}/common.sh"

if ! is_container_runtime_available; then
  echo "Container engine not available. Running a non-containerized command"
  WORKING_DIRECTORY="$(pwd)"

  VIRTUAL_ENVIRONMENT_PATH="${WORKING_DIRECTORY}/.venv-ansible"
  PIP_REQUIREMENTS_FILE_PATH="${PIP_REQUIREMENTS_FILE_PATH:-"${WORKING_DIRECTORY}/docker/ansible/requirements.txt"}"
  create_and_activate_python_virtual_environment "${VIRTUAL_ENVIRONMENT_PATH}" "${PIP_REQUIREMENTS_FILE_PATH}"

  ANSIBLE_DIRECTORY="${WORKING_DIRECTORY}/docker/ansible/etc/ansible"
  ANSIBLE_ROLES_PATH="${ANSIBLE_ROLES_PATH:-"${ANSIBLE_DIRECTORY}/roles"}"
  export ANSIBLE_ROLES_PATH

  # Install Ansible requirements
  ansible-galaxy install -r "${WORKING_DIRECTORY}/docker/ansible/etc/ansible/requirements.yml"

  COMMAND_TO_RUN="${1}"
else
  ANSIBLE_CONTAINER_IMAGE_CONTEXT_PATH="${CURRENT_WORKING_DIRECTORY}/docker/ansible"
  ANSIBLE_PIP_REQUIREMENTS_FILE_PATH="${ANSIBLE_CONTAINER_IMAGE_CONTEXT_PATH}/requirements.txt"
  echo "Loading Ansible version from ${ANSIBLE_PIP_REQUIREMENTS_FILE_PATH}"
  ANSIBLE_CONTAINER_IMAGE_TAG="$(grep <"${ANSIBLE_PIP_REQUIREMENTS_FILE_PATH}" "ansible" | awk -F '==' '{print $2}')"
  echo "Ansible container image tag to run: ${ANSIBLE_CONTAINER_IMAGE_TAG}"
  ANSIBLE_CONTAINER_IMAGE_ID="ferrarimarco/ansible:${ANSIBLE_CONTAINER_IMAGE_TAG}"

  echo "Building Ansible container image (${ANSIBLE_CONTAINER_IMAGE_ID}) from ${ANSIBLE_CONTAINER_IMAGE_CONTEXT_PATH}"
  docker build \
    --tag "${ANSIBLE_CONTAINER_IMAGE_ID}" \
    "${ANSIBLE_CONTAINER_IMAGE_CONTEXT_PATH}"

  COMMAND_TO_RUN="docker run"
  if [ -t 0 ]; then
    COMMAND_TO_RUN="${COMMAND_TO_RUN} -it"
  fi
  if [ -z "${MOLECULE_DISTRO}" ]; then
    COMMAND_TO_RUN="${COMMAND_TO_RUN} --env MOLECULE_DISTRO=${MOLECULE_DISTRO}"
    COMMAND_TO_RUN="${COMMAND_TO_RUN} -v /var/run/docker.sock:/var/run/docker.sock"
  fi
  COMMAND_TO_RUN="${COMMAND_TO_RUN} --rm"
  COMMAND_TO_RUN="${COMMAND_TO_RUN} -v ${ANSIBLE_CONTAINER_IMAGE_CONTEXT_PATH}/etc/ansible:/etc/ansible"
  COMMAND_TO_RUN="${COMMAND_TO_RUN} --workdir=/etc/ansible"
  COMMAND_TO_RUN="${COMMAND_TO_RUN} ${ANSIBLE_CONTAINER_IMAGE_ID}"
  COMMAND_TO_RUN="${COMMAND_TO_RUN} ${1}"
fi

echo "Running command: ${COMMAND_TO_RUN}"
eval "${COMMAND_TO_RUN}"
