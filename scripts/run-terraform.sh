#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

# shellcheck source=/dev/null
. "./scripts/common.sh"

declare -a TERRAFORM_SERVICES
readarray -t TERRAFORM_SERVICES < <(find "${TERRAFORM_DIR_PATH}" -maxdepth 1 -name '[0-9]*' -type d | sort 2>&1)

declare -a TERRAFORM_COMMAND
declare -a TERRAFORM_INIT_COMMAND

mkdir --parents "${TERRAFORM_LOCAL_BACKEND_CONFIG_DIR_PATH}"

for tf_service in "${TERRAFORM_SERVICES[@]}"; do
  tf_service_name="$(basename "${tf_service}")"
  break_line
  echo "Running ${tf_service_name} Terraform service"

  TERRAFORM_COMMAND=(
    terraform
    -chdir="${tf_service}"
  )

  TERRAFORM_SERVICE_LOCAL_BACKEND_DIRECTORY_PATH="${TERRAFORM_LOCAL_BACKEND_DIRECTORY_PATH}/${tf_service_name}"
  mkdir --parents "${TERRAFORM_SERVICE_LOCAL_BACKEND_DIRECTORY_PATH}"

  TERRAFORM_INIT_COMMAND=(
    "${TERRAFORM_COMMAND[@]}"
    init
  )

  TERRAFORM_APPLY_COMMAND=(
    "${TERRAFORM_COMMAND[@]}"
    apply
  )

  TERRAFORM_LOCAL_BACKEND_STATE_FILE_PATH="${TERRAFORM_SERVICE_LOCAL_BACKEND_DIRECTORY_PATH}/terraform.tfstate"
  if [[ "${tf_service_name}" == "000-initialization" ]] &&
    [[ ! -f "${TERRAFORM_LOCAL_BACKEND_STATE_FILE_PATH}" ]]; then
    echo "Initializing local backend on the first run: ${TERRAFORM_INIT_COMMAND[*]}"
    "${TERRAFORM_INIT_COMMAND[@]}"
    "${TERRAFORM_APPLY_COMMAND[@]}"
  fi

  TERRAFORM_FIRST_INIT_DATA_DIR_PATH="${tf_service}/.terraform"
  if [[ -e "${TERRAFORM_FIRST_INIT_DATA_DIR_PATH}" ]]; then
    # Move the terraform data dir to the local backend directory so we can make
    # terraform service fully environment-agnostic
    mv -v "${TERRAFORM_FIRST_INIT_DATA_DIR_PATH}" "${TERRAFORM_SERVICE_LOCAL_BACKEND_DIRECTORY_PATH}/"
  fi

  export TF_DATA_DIR="${TERRAFORM_SERVICE_LOCAL_BACKEND_DIRECTORY_PATH}/.terraform"

  TERRAFORM_LOCAL_BACKEND_CONFIGURATION_PATH="${TERRAFORM_LOCAL_BACKEND_CONFIG_DIR_PATH}/${tf_service_name}.local.tfbackend"
  # Run the command again and migrate state after configuring the final local backend path
  TERRAFORM_INIT_COMMAND+=(
    -backend-config="${TERRAFORM_LOCAL_BACKEND_CONFIGURATION_PATH}"
    -migrate-state
    -force-copy
  )
  "${TERRAFORM_INIT_COMMAND[@]}"

  case "${tf_service_name}" in
  "200-proxmox")
    TERRAFORM_PVE1_ROOT_CREDENTIALS_FILE_PATH="${TERRAFORM_ENVIRONMENTS_DIR_PATH}/proxmox-pve1-root-secrets.tfvars"
    if [[ ! -f "${TERRAFORM_PVE1_ROOT_CREDENTIALS_FILE_PATH}" ]]; then
      echo "Skip ${tf_service} because root credentials file (${TERRAFORM_PVE1_ROOT_CREDENTIALS_FILE_PATH}) is not available"
      continue
    fi
    "${TERRAFORM_APPLY_COMMAND[@]}" \
      -var-file="${TERRAFORM_ENVIRONMENTS_DIR_PATH}/proxmox-pve1.tfvars" \
      -var-file="${TERRAFORM_PVE1_ROOT_CREDENTIALS_FILE_PATH}"
    ;;
  "201-proxmox-workloads")
    "${TERRAFORM_COMMAND[@]}" \
      apply \
      -var-file="${TERRAFORM_ENVIRONMENTS_DIR_PATH}/proxmox-pve1.tfvars" \
      -var-file="${TERRAFORM_ENVIRONMENTS_DIR_PATH}/proxmox-pve1-secrets.tfvars"
    ;;
  *)
    "${TERRAFORM_APPLY_COMMAND[@]}"
    ;;
  esac
done
