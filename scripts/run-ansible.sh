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

  VIRTUAL_ENVIRONMENT_PATH="${CURRENT_WORKING_DIRECTORY}/.venv-ansible"
  PIP_REQUIREMENTS_FILE_PATH="${PIP_REQUIREMENTS_FILE_PATH:-"${CURRENT_WORKING_DIRECTORY}/docker/ansible/requirements.txt"}"
  create_and_activate_python_virtual_environment "${VIRTUAL_ENVIRONMENT_PATH}" "${PIP_REQUIREMENTS_FILE_PATH}"

  ANSIBLE_DIRECTORY="${CURRENT_WORKING_DIRECTORY}/docker/ansible/etc/ansible"
  ANSIBLE_ROLES_PATH="${ANSIBLE_ROLES_PATH:-"${ANSIBLE_DIRECTORY}/roles"}"
  export ANSIBLE_ROLES_PATH

  # Install Ansible requirements
  ansible-galaxy install -r "${CURRENT_WORKING_DIRECTORY}/docker/ansible/etc/ansible/requirements.yml"
else
  ANSIBLE_CONTAINER_IMAGE_CONTEXT_PATH="${CURRENT_WORKING_DIRECTORY}/docker/ansible"
  ANSIBLE_PIP_REQUIREMENTS_FILE_PATH="${ANSIBLE_CONTAINER_IMAGE_CONTEXT_PATH}/requirements.txt"
  echo "Loading Ansible version from ${ANSIBLE_PIP_REQUIREMENTS_FILE_PATH}"
  ANSIBLE_CONTAINER_IMAGE_TAG="$(grep <"${ANSIBLE_PIP_REQUIREMENTS_FILE_PATH}" "ansible" | awk -F '==' '{print $2}')"
  echo "Ansible container image tag to run: ${ANSIBLE_CONTAINER_IMAGE_TAG}"
  ANSIBLE_CONTAINER_IMAGE_ID="ferrarimarco/ansible:${ANSIBLE_CONTAINER_IMAGE_TAG}"
  echo "Ansible container image id: ${ANSIBLE_CONTAINER_IMAGE_ID}"
  ANSIBLE_CONTAINER_IMAGE_BUILD_TARGET="${ANSIBLE_CONTAINER_IMAGE_BUILD_TARGET:-"ansible"}"
  echo "Ansible container image build target: ${ANSIBLE_CONTAINER_IMAGE_BUILD_TARGET}"

  if [ -n "${MOLECULE_DISTRO:-}" ] && [ "${ANSIBLE_CONTAINER_IMAGE_BUILD_TARGET:-}" = "ansible" ]; then
    ANSIBLE_CONTAINER_IMAGE_BUILD_TARGET="molecule"
    echo "Set Ansible container image build target to ${ANSIBLE_CONTAINER_IMAGE_BUILD_TARGET}"
  fi

  echo "Building Ansible container image (${ANSIBLE_CONTAINER_IMAGE_ID}) from ${ANSIBLE_CONTAINER_IMAGE_CONTEXT_PATH}"
  docker build \
    --tag "${ANSIBLE_CONTAINER_IMAGE_ID}" \
    --target "${ANSIBLE_CONTAINER_IMAGE_BUILD_TARGET:-"ansible"}" \
    "${ANSIBLE_CONTAINER_IMAGE_CONTEXT_PATH}"

  COMMAND_TO_RUN="docker run"
  if [ -t 0 ]; then
    COMMAND_TO_RUN="${COMMAND_TO_RUN} -it"
  fi
  if [ -n "${MOLECULE_DISTRO:-}" ]; then
    COMMAND_TO_RUN="${COMMAND_TO_RUN} --env MOLECULE_DISTRO=${MOLECULE_DISTRO}"
    COMMAND_TO_RUN="${COMMAND_TO_RUN} -v /var/run/docker.sock:/var/run/docker.sock"
  fi
  COMMAND_TO_RUN="${COMMAND_TO_RUN} --rm"
  COMMAND_TO_RUN="${COMMAND_TO_RUN} -v ${ANSIBLE_CONTAINER_IMAGE_CONTEXT_PATH}/etc/ansible:/etc/ansible"
  COMMAND_TO_RUN="${COMMAND_TO_RUN} --workdir=/etc/ansible"
  COMMAND_TO_RUN="${COMMAND_TO_RUN} ${ANSIBLE_CONTAINER_IMAGE_ID}"
fi

ANSIBLE_PLAYBOOK_PATH="${ANSIBLE_PLAYBOOK_PATH:-"docker/ansible/etc/ansible/playbooks/main.yaml"}"
ANSIBLE_INVENTORY_PATH="${ANSIBLE_INVENTORY_PATH:-"docker/ansible/etc/ansible/inventory/hosts.yml"}"
ANSIBLE_VAULT_ID="${ANSIBLE_VAULT_ID:-"home_lab_vault"}"
ANSIBLE_VAULT_DECRYPT_MODE="${ANSIBLE_VAULT_DECRYPT_MODE:-"prompt"}"

DEFAULT_ANSIBLE_COMMAND_TO_RUN="ansible-playbook"
DEFAULT_ANSIBLE_COMMAND_TO_RUN="${DEFAULT_ANSIBLE_COMMAND_TO_RUN} --inventory ${ANSIBLE_INVENTORY_PATH}"
DEFAULT_ANSIBLE_COMMAND_TO_RUN="${DEFAULT_ANSIBLE_COMMAND_TO_RUN} --vault-id ${ANSIBLE_VAULT_ID}@${ANSIBLE_VAULT_DECRYPT_MODE}"
DEFAULT_ANSIBLE_COMMAND_TO_RUN="${DEFAULT_ANSIBLE_COMMAND_TO_RUN} ${ANSIBLE_PLAYBOOK_PATH}"

ANSIBLE_COMMAND_GATHER_FACTS_INVENTORY="ansible -m ansible.builtin.setup --inventory ${ANSIBLE_INVENTORY_PATH} all"

COMMAND_TO_RUN="${COMMAND_TO_RUN:-""}"

if [ -n "${1:-}" ]; then
  COMMAND_TO_RUN="${COMMAND_TO_RUN} ${1}"
elif [ "${ANSIBLE_GATHER_FACTS_INVENTORY:-"false"}" = "true" ]; then
  COMMAND_TO_RUN="${COMMAND_TO_RUN} ${ANSIBLE_COMMAND_GATHER_FACTS_INVENTORY}"
else
  COMMAND_TO_RUN="${COMMAND_TO_RUN} ${DEFAULT_ANSIBLE_COMMAND_TO_RUN}"
fi

# --check: enable check mode (dry-run)
# --diff: enable diff mode
# --list-tags: list the defined Ansible tags
# --tags: run tagged tasks. Example: --tags='tag1,tag2'. To run untagged tasks: --tags untagged
#   When running tasks related to specific stacks, you need to also run untagged tasks.
#   Example: --tags='monitoring,monitoring-backend,monitoring-nut' --tags untagged
if [ -n "${ADDITIONAL_ANSIBLE_FLAGS:-""}" ]; then
  COMMAND_TO_RUN="${COMMAND_TO_RUN} ${ADDITIONAL_ANSIBLE_FLAGS:-""}"
fi

echo "Running command: ${COMMAND_TO_RUN}"
eval "${COMMAND_TO_RUN}"
