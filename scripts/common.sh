#!/usr/bin/env sh

set -o errexit
set -o nounset

# shellcheck disable=SC2034
ERR_ARGUMENT_EVAL=2

is_command_available() {
  if command -v "${1}" >/dev/null 2>&1; then
    return 0
  else
    return 1
  fi
}

is_container_runtime_available() {
  if is_command_available "docker" && [ -e /var/run/docker.sock ]; then
    return 0
  else
    return 1
  fi
}

activate_python_virtual_environment() {
  VENV_PATH="${1}"

  if [ -z "${VIRTUAL_ENV-}" ]; then
    echo "Activating the virtual environment in ${VENV_PATH}"
    # shellcheck source=/dev/null
    . "${VENV_PATH}/bin/activate"
  else
    echo "You're already inside a Python virtual environment. Skipping the activation of ${VENV_PATH}"
  fi

  unset VENV_PATH
}

is_python_virtual_environment_up_to_date() {
  PYTHON_VIRTUAL_ENVIRONMENT_CHECK_RETURN_CODE=0
  if [ ! -e "${1}" ]; then
    # The virtual environment doesn't exist, so it can't be up to date by definition
    PYTHON_VIRTUAL_ENVIRONMENT_CHECK_RETURN_CODE=1
  else
    activate_python_virtual_environment "${1}"
    if [ "$(pip list --outdated | wc -l)" -eq 0 ]; then
      echo "The Python virtual environment (${1}) is up to date."
    else
      echo "The Python virtual environment (${1}) is not up to date. Outdated packages:"
      pip list --outdated
      PYTHON_VIRTUAL_ENVIRONMENT_CHECK_RETURN_CODE=2
    fi
    deactivate
  fi

  return ${PYTHON_VIRTUAL_ENVIRONMENT_CHECK_RETURN_CODE}
}

compress_file() {
  SOURCE_FILE_PATH="${1}"

  echo "Compressing ${SOURCE_FILE_PATH}..."
  xz -9 \
    --compress \
    --force \
    --threads=0 \
    --verbose \
    "${SOURCE_FILE_PATH}"

  unset SOURCE_FILE_PATH
}

create_and_activate_python_virtual_environment() {
  PYTHON_VIRTUAL_ENVIRONMENT_PATH="${1}"
  PIP_REQUIREMENTS_PATH="${2:-""}"
  _FORCE_UPDATE_PYTHON_VIRTUAL_ENVIRONMENT="${3:-"false"}"

  if [ -e "${PYTHON_VIRTUAL_ENVIRONMENT_PATH}" ] && ! is_python_virtual_environment_up_to_date "${PYTHON_VIRTUAL_ENVIRONMENT_PATH}" && [ "${_FORCE_UPDATE_PYTHON_VIRTUAL_ENVIRONMENT}" = "true" ]; then
    echo "The ${PYTHON_VIRTUAL_ENVIRONMENT_PATH} virtual environment already exists but it's not up to date. Deleting it..."
    rm -rf "${PYTHON_VIRTUAL_ENVIRONMENT_PATH}"
  fi

  if [ ! -e "${PYTHON_VIRTUAL_ENVIRONMENT_PATH}" ]; then
    echo "Creating a virtual environment in ${PYTHON_VIRTUAL_ENVIRONMENT_PATH}"
    python3 -m venv "${PYTHON_VIRTUAL_ENVIRONMENT_PATH}" --upgrade-deps

    activate_python_virtual_environment "${PYTHON_VIRTUAL_ENVIRONMENT_PATH}"

    echo "Ensure wheel is installed and up to date"
    pip3 install --upgrade wheel

    if [ -n "${PIP_REQUIREMENTS_PATH}" ]; then
      if [ ! -r "${PIP_REQUIREMENTS_PATH}" ]; then
        echo "Error: ${PIP_REQUIREMENTS_PATH} doesn't exist"
        exit 1
      fi
      echo "Installing dependencies from requirements file: ${PIP_REQUIREMENTS_PATH}"
      pip3 install -r "${PIP_REQUIREMENTS_PATH}"
    fi
  else
    echo "The virtual environment already exists: ${PYTHON_VIRTUAL_ENVIRONMENT_PATH}"
    activate_python_virtual_environment "${PYTHON_VIRTUAL_ENVIRONMENT_PATH}"
  fi

  unset PIP_REQUIREMENTS_PATH
  unset PYTHON_VIRTUAL_ENVIRONMENT_PATH
  unset _FORCE_UPDATE_PYTHON_VIRTUAL_ENVIRONMENT
}
