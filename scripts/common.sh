#!/usr/bin/env sh

set -o errexit
set -o nounset

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

  if [ ! -e "${PYTHON_VIRTUAL_ENVIRONMENT_PATH}" ]; then
    echo "Creating a virtual environment in ${PYTHON_VIRTUAL_ENVIRONMENT_PATH}"
    python3 -m venv "${PYTHON_VIRTUAL_ENVIRONMENT_PATH}"

    activate_python_virtual_environment "${PYTHON_VIRTUAL_ENVIRONMENT_PATH}"

    echo "Ensure pip, setuptools, and wheel are installed and up to date"
    pip3 install --upgrade pip setuptools wheel

    if [ -n "${PIP_REQUIREMENTS_PATH}" ] && [ -r "${PIP_REQUIREMENTS_PATH}" ]; then
      echo "Installing dependencies from requirements file: ${PIP_REQUIREMENTS_PATH}"
      pip3 install -r "${PIP_REQUIREMENTS_PATH}"
    fi
  else
    echo "The virtual environment already exists. Skipping creation."
    activate_python_virtual_environment "${PYTHON_VIRTUAL_ENVIRONMENT_PATH}"
  fi

  unset PIP_REQUIREMENTS_PATH
  unset PYTHON_VIRTUAL_ENVIRONMENT_PATH
}
