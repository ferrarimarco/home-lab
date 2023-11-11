#!/usr/bin/env sh

set -o errexit
set -o nounset

_PIP_REQUIREMENTS_FILE_HASH_PATH="${PYTHON_VIRTUAL_ENVIRONMENT_PATH}/.pip_requirements_hash"

if [ -f "${_PIP_REQUIREMENTS_FILE_PATH}" ]; then
  echo "[Error] Cannot find the pip requirements file: ${_PIP_REQUIREMENTS_FILE_PATH}"
  exit 1
fi

if [ ! -f "${_PIP_REQUIREMENTS_FILE_HASH_PATH}" ] || [ "$(sha256sum "${HOST_CONFIGURATION_SERVICE_PIP_REQUIREMENTS_FILE_PATH}")" != "$(cat "${_PIP_REQUIREMENTS_FILE_HASH_PATH}")" ]; then
  rm -rfv "${PYTHON_VIRTUAL_ENVIRONMENT_PATH}"
  python -m venv "${PYTHON_VIRTUAL_ENVIRONMENT_PATH}" --upgrade-deps
  sha256sum "${HOST_CONFIGURATION_SERVICE_PIP_REQUIREMENTS_FILE_PATH}" >"${_PIP_REQUIREMENTS_FILE_HASH_PATH}"

  # shellcheck source=/dev/null
  . "${PYTHON_VIRTUAL_ENVIRONMENT_PATH}/bin/activate"

  pip install --upgrade wheel
  pip install -r "${HOST_CONFIGURATION_SERVICE_PIP_REQUIREMENTS_FILE_PATH}"
else
  # Activate the virtual environment in case we reuse an existing one
  # shellcheck source=/dev/null
  . "${PYTHON_VIRTUAL_ENVIRONMENT_PATH}/bin/activate"
fi
