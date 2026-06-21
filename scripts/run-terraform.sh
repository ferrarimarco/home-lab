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

  TERRAFORM_COMMAND=(
    terraform
    -chdir="${tf_service}"
  )

  TERRAFORM_SERVICE_LOCAL_BACKEND_DIRECTORY_PATH="${TERRAFORM_LOCAL_BACKEND_DIRECTORY_PATH}/${tf_service_name}"
  mkdir --parents "${TERRAFORM_SERVICE_LOCAL_BACKEND_DIRECTORY_PATH}"

  TERRAFORM_LOCAL_BACKEND_STATE_FILE_PATH="${TERRAFORM_SERVICE_LOCAL_BACKEND_DIRECTORY_PATH}/terraform.tfstate"
  export TF_DATA_DIR="${TERRAFORM_SERVICE_LOCAL_BACKEND_DIRECTORY_PATH}/.terraform"

  TERRAFORM_INIT_COMMAND=(
    "${TERRAFORM_COMMAND[@]}"
    init
  )

  TERRAFORM_APPLY_COMMAND=(
    "${TERRAFORM_COMMAND[@]}"
    apply
  )

  TERRAFORM_OUTPUT_COMMAND=(
    "${TERRAFORM_COMMAND[@]}"
    output
    -json
  )

  # Don't emit any output before having the chance of checking if we need to emit JSON output
  if [[ "${1:-}" == "output" ]]; then
    if [[ "${2}" == "${tf_service_name}" ]]; then
      if [[ -n "${3:-}" ]]; then
        TERRAFORM_OUTPUT_COMMAND+=(
          "${3}"
        )
      fi
      "${TERRAFORM_OUTPUT_COMMAND[@]}"
      exit 0
    else
      continue
    fi
  fi

  break_line
  echo "Running ${tf_service_name} Terraform service"

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

  TERRAFORM_LOCAL_BACKEND_CONFIGURATION_PATH="${TERRAFORM_LOCAL_BACKEND_CONFIG_DIR_PATH}/${tf_service_name}.local.tfbackend"
  # Run the command again and migrate state after configuring the final local backend path
  TERRAFORM_INIT_COMMAND+=(
    -backend-config="${TERRAFORM_LOCAL_BACKEND_CONFIGURATION_PATH}"
    -migrate-state
    -force-copy
  )
  "${TERRAFORM_INIT_COMMAND[@]}"

  case "${tf_service_name}" in
  "000-initialization")
    "${TERRAFORM_APPLY_COMMAND[@]}" \
      -var-file="${TERRAFORM_ENVIRONMENTS_DIR_PATH}/proxmox.tfvars"
    ;;
  "200-proxmox-iac-automation-init")
    TERRAFORM_ROOT_CREDENTIALS_FILE_PATH="${TERRAFORM_ENVIRONMENTS_DIR_PATH}/proxmox-root-secrets.tfvars"
    if [[ ! -f "${TERRAFORM_ROOT_CREDENTIALS_FILE_PATH}" ]]; then
      echo "Skip ${tf_service} because root credentials file (${TERRAFORM_ROOT_CREDENTIALS_FILE_PATH}) is not available"
      continue
    fi
    "${TERRAFORM_APPLY_COMMAND[@]}" \
      -var-file="${TERRAFORM_ENVIRONMENTS_DIR_PATH}/proxmox.tfvars" \
      -var-file="${TERRAFORM_ROOT_CREDENTIALS_FILE_PATH}"
    ;;
  "210-proxmox-storage" | "220-proxmox-workloads")
    "${TERRAFORM_APPLY_COMMAND[@]}" \
      -var-file="${TERRAFORM_ENVIRONMENTS_DIR_PATH}/proxmox.tfvars" \
      -var-file="${TERRAFORM_ENVIRONMENTS_DIR_PATH}/proxmox-secrets.tfvars.json"
    ;;
  *)
    "${TERRAFORM_APPLY_COMMAND[@]}"
    ;;
  esac
done
