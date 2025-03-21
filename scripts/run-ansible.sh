#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

# Doesn't follow symlinks, but it's likely expected for most users
SCRIPT_BASENAME="$(basename "${0}")"
SCRIPT_DIRECTORY_PATH="$(dirname "${0}")"
CURRENT_WORKING_DIRECTORY="$(pwd)"

echo "This script (name: ${SCRIPT_BASENAME}, directory path: ${SCRIPT_DIRECTORY_PATH}) has been invoked with: ${0} $*"
echo "Current working directory: ${CURRENT_WORKING_DIRECTORY}"

# shellcheck source=/dev/null
. "${SCRIPT_DIRECTORY_PATH}/common.sh"

ANSIBLE_CONTAINER_IMAGE_CONTEXT_PATH="${CURRENT_WORKING_DIRECTORY}/docker/ansible"
echo "ANSIBLE_CONTAINER_IMAGE_CONTEXT_PATH: ${ANSIBLE_CONTAINER_IMAGE_CONTEXT_PATH}"

ANSIBLE_PIP_REQUIREMENTS_FILE_PATH="${ANSIBLE_CONTAINER_IMAGE_CONTEXT_PATH}/requirements.txt"
echo "ANSIBLE_PIP_REQUIREMENTS_FILE_PATH: ${ANSIBLE_PIP_REQUIREMENTS_FILE_PATH}"

ANSIBLE_DIRECTORY="${CURRENT_WORKING_DIRECTORY}/config/ansible"
echo "ANSIBLE_DIRECTORY: ${ANSIBLE_DIRECTORY}"

ANSIBLE_VAULT_ID="${ANSIBLE_VAULT_ID:-"home_lab_vault"}"
echo "ANSIBLE_VAULT_ID: ${ANSIBLE_VAULT_ID}"

ANSIBLE_VAULT_DECRYPT_MODE="${ANSIBLE_VAULT_DECRYPT_MODE:-"prompt"}"
echo "ANSIBLE_VAULT_DECRYPT_MODE: ${ANSIBLE_VAULT_DECRYPT_MODE}"

ANSIBLE_VAULT_PASSWORD_FILE_NAME="${ANSIBLE_VAULT_ID}_password_file"
echo "ANSIBLE_VAULT_PASSWORD_FILE_NAME: ${ANSIBLE_VAULT_PASSWORD_FILE_NAME}"

ANSIBLE_VAULT_PASSWORD_FILE_PATH="${ANSIBLE_DIRECTORY}/${ANSIBLE_VAULT_PASSWORD_FILE_NAME}"
echo "ANSIBLE_VAULT_PASSWORD_FILE_PATH: ${ANSIBLE_VAULT_PASSWORD_FILE_PATH}"

echo "Loading Ansible version from ${ANSIBLE_PIP_REQUIREMENTS_FILE_PATH}"
ANSIBLE_CONTAINER_IMAGE_TAG="$(grep <"${ANSIBLE_PIP_REQUIREMENTS_FILE_PATH}" "ansible" | awk -F '==' '{print $2}')"
echo "Ansible container image tag to run: ${ANSIBLE_CONTAINER_IMAGE_TAG}"
ANSIBLE_CONTAINER_IMAGE_ID="ferrarimarco/ansible:${ANSIBLE_CONTAINER_IMAGE_TAG}"
echo "Ansible container image id: ${ANSIBLE_CONTAINER_IMAGE_ID}"
ANSIBLE_CONTAINER_IMAGE_BUILD_TARGET="${ANSIBLE_CONTAINER_IMAGE_BUILD_TARGET:-"ansible"}"
echo "Ansible container image build target: ${ANSIBLE_CONTAINER_IMAGE_BUILD_TARGET}"

if [ -n "${ANSIBLE_TEST_DISTRO:-}" ] && [ "${ANSIBLE_CONTAINER_IMAGE_BUILD_TARGET:-}" = "ansible" ]; then
  ANSIBLE_CONTAINER_IMAGE_BUILD_TARGET="molecule"
  echo "Set Ansible container image build target to ${ANSIBLE_CONTAINER_IMAGE_BUILD_TARGET}"
fi

echo "Building Ansible container image (${ANSIBLE_CONTAINER_IMAGE_ID}) from ${ANSIBLE_CONTAINER_IMAGE_CONTEXT_PATH}"
docker build \
  --build-context=ansible-configuration="${ANSIBLE_DIRECTORY}" \
  --tag "${ANSIBLE_CONTAINER_IMAGE_ID}" \
  --target "${ANSIBLE_CONTAINER_IMAGE_BUILD_TARGET:-"ansible"}" \
  "${ANSIBLE_CONTAINER_IMAGE_CONTEXT_PATH}"

COMMAND_TO_RUN="docker run"
if [ -t 0 ]; then
  COMMAND_TO_RUN="${COMMAND_TO_RUN} -it"
fi

if [ -n "${ANSIBLE_TEST_DISTRO:-}" ]; then
  ANSIBLE_TEST_PLAYBOOK_PATH="../../playbooks/${ANSIBLE_TEST_PLAYBOOK_NAME}.yaml"
  ANSIBLE_TEST_PLAYBOOK_FULL_PATH="config/ansible/molecule/default/${ANSIBLE_TEST_PLAYBOOK_PATH}"
  if [ ! -f "${ANSIBLE_TEST_PLAYBOOK_FULL_PATH}" ]; then
    echo "The playbook file does not exist: ${ANSIBLE_TEST_PLAYBOOK_FULL_PATH}"
    exit "${ERR_ANSIBLE_TEST_MISSING_PLAYBOOK}"
  fi

  COMMAND_TO_RUN="${COMMAND_TO_RUN} --env ANSIBLE_TEST_DISTRO=${ANSIBLE_TEST_DISTRO}"
  COMMAND_TO_RUN="${COMMAND_TO_RUN} --env ANSIBLE_TEST_PLAYBOOK_PATH=${ANSIBLE_TEST_PLAYBOOK_PATH}"

  COMMAND_TO_RUN="${COMMAND_TO_RUN} -v /var/run/docker.sock:/var/run/docker.sock"
else
  SSH_AUTH_SOCKET_DESTINATION_PATH="/ssh-agent"
  COMMAND_TO_RUN="${COMMAND_TO_RUN} --env SSH_AUTH_SOCK=${SSH_AUTH_SOCKET_DESTINATION_PATH}"

  if [ -z "${SSH_AUTH_SOCK:-}" ]; then
    echo "SSH_AUTH_SOCK is not set. Ensure that the SSH agent is running, and that you added the private keys to connect to nodes to the agent."
    exit 1
  fi

  COMMAND_TO_RUN="${COMMAND_TO_RUN} -v ${SSH_AUTH_SOCK}:${SSH_AUTH_SOCKET_DESTINATION_PATH}"

  if [ ! -f "${ANSIBLE_VAULT_PASSWORD_FILE_PATH}" ]; then
    echo "The Ansible vault password file does not exist: ${ANSIBLE_VAULT_PASSWORD_FILE_PATH}"
    exit "${ERR_ANSIBLE_MISSING_PASSWORD_FILE}"
  fi
fi

ANSIBLE_DIRECTORY_INSIDE_CONTAINER_MOUNT_PATH="/etc/ansible"

COMMAND_TO_RUN="${COMMAND_TO_RUN} --rm"
COMMAND_TO_RUN="${COMMAND_TO_RUN} -v ${ANSIBLE_DIRECTORY}:${ANSIBLE_DIRECTORY_INSIDE_CONTAINER_MOUNT_PATH}"
COMMAND_TO_RUN="${COMMAND_TO_RUN} --workdir=${ANSIBLE_DIRECTORY_INSIDE_CONTAINER_MOUNT_PATH}"
COMMAND_TO_RUN="${COMMAND_TO_RUN} ${ANSIBLE_CONTAINER_IMAGE_ID}"

ANSIBLE_VAULT_PASSWORD_FILE_DESTINATION_PATH="${ANSIBLE_DIRECTORY_INSIDE_CONTAINER_MOUNT_PATH}/${ANSIBLE_VAULT_PASSWORD_FILE_NAME}"
echo "ANSIBLE_VAULT_PASSWORD_FILE_DESTINATION_PATH: ${ANSIBLE_VAULT_PASSWORD_FILE_DESTINATION_PATH}"
ANSIBLE_VAULT_FULL_ID="${ANSIBLE_VAULT_ID}@${ANSIBLE_VAULT_PASSWORD_FILE_DESTINATION_PATH}"
echo "ANSIBLE_VAULT_FULL_ID: ${ANSIBLE_VAULT_FULL_ID}"

if [ -n "${1:-}" ]; then
  COMMAND_TO_RUN="${COMMAND_TO_RUN} ${1}"
elif [ "${ANSIBLE_EDIT_VAULT_FILE:-"false"}" = "true" ]; then
  ANSIBLE_VAULT_FILE_PATH="${ANSIBLE_DIRECTORY_INSIDE_CONTAINER_MOUNT_PATH}/${ANSIBLE_VAULT_FILE_PATH:-"inventory/group_vars/all/vault.yaml"}"
  ANSIBLE_COMMAND_EDIT_VAULT_FILE="ansible-vault edit --vault-id ${ANSIBLE_VAULT_FULL_ID} ${ANSIBLE_VAULT_FILE_PATH}"
  COMMAND_TO_RUN="${COMMAND_TO_RUN} ${ANSIBLE_COMMAND_EDIT_VAULT_FILE}"
else
  ANSIBLE_PLAYBOOK_FILE_NAME="${ANSIBLE_PLAYBOOK_FILE_NAME:-"main.yaml"}"
  ANSIBLE_PLAYBOOK_PATH="${ANSIBLE_PLAYBOOK_PATH:-"${ANSIBLE_DIRECTORY_INSIDE_CONTAINER_MOUNT_PATH}/playbooks/${ANSIBLE_PLAYBOOK_FILE_NAME}"}"
  ANSIBLE_INVENTORY_PATH="${ANSIBLE_INVENTORY_PATH:-"${ANSIBLE_DIRECTORY_INSIDE_CONTAINER_MOUNT_PATH}/inventory/hosts.yml"}"
  echo "ANSIBLE_PLAYBOOK_PATH: ${ANSIBLE_PLAYBOOK_PATH}"
  echo "ANSIBLE_INVENTORY_PATH: ${ANSIBLE_INVENTORY_PATH}"

  DEFAULT_ANSIBLE_COMMAND_TO_RUN="ansible-playbook"
  DEFAULT_ANSIBLE_COMMAND_TO_RUN="${DEFAULT_ANSIBLE_COMMAND_TO_RUN} --inventory ${ANSIBLE_INVENTORY_PATH}"
  DEFAULT_ANSIBLE_COMMAND_TO_RUN="${DEFAULT_ANSIBLE_COMMAND_TO_RUN} --vault-id ${ANSIBLE_VAULT_FULL_ID}"

  # --ask-pass: ask for password to connect to hosts
  # --connection paramiko: use paramiko to connect to the host (useful to connect to hosts using SSH and authenticating with a password)
  # --check: enable check mode (dry-run)
  # --diff: enable diff mode
  # --limit "host1": only run against host1. host1 must be in the inventory
  # --list-tags: list the defined Ansible tags
  # --tags: run tagged tasks. Example: --tags='tag1,tag2'. To run untagged tasks: --tags untagged
  #   When running tasks related to specific stacks, you need to also run untagged tasks.
  #   Example: --tags='monitoring,monitoring-backend,monitoring-nut' --tags untagged
  if [ -n "${ADDITIONAL_ANSIBLE_FLAGS:-""}" ]; then
    DEFAULT_ANSIBLE_COMMAND_TO_RUN="${DEFAULT_ANSIBLE_COMMAND_TO_RUN} ${ADDITIONAL_ANSIBLE_FLAGS:-""}"
  fi

  DEFAULT_ANSIBLE_COMMAND_TO_RUN="${DEFAULT_ANSIBLE_COMMAND_TO_RUN} ${ANSIBLE_PLAYBOOK_PATH}"

  COMMAND_TO_RUN="${COMMAND_TO_RUN} ${DEFAULT_ANSIBLE_COMMAND_TO_RUN}"
fi

echo "Running command: ${COMMAND_TO_RUN}"
eval "${COMMAND_TO_RUN}"
