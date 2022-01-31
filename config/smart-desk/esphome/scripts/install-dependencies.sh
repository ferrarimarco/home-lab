#!/usr/bin/env sh

set -o errexit
set -o nounset

# Doesn't follow symlinks, but it's likely expected for most users
SCRIPT_BASENAME="$(basename "${0}")"

echo "This script (${SCRIPT_BASENAME}) has been invoked with: $0 $*"

WORKING_DIRECTORY="$(pwd)"
VIRTUAL_ENVIRONMENT_PATH="${WORKING_DIRECTORY}/.venv"

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

if [ ! -e "${VIRTUAL_ENVIRONMENT_PATH}" ]; then
  echo "Creating a virtual environment in ${VIRTUAL_ENVIRONMENT_PATH}"
  python3 -m venv "${VIRTUAL_ENVIRONMENT_PATH}"

  activate_python_virtual_environment "${VIRTUAL_ENVIRONMENT_PATH}"

  echo "Installing dependencies"
  pip3 install -r requirements.txt
else
  echo "The virtual environment already exists. Skipping creation."
fi

# Ensure we're in a Python virtual environment, because we might source this script
# from other scripts
activate_python_virtual_environment "${VIRTUAL_ENVIRONMENT_PATH}"

echo "Getting ESPHome version"
esphome --verbose version
