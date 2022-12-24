#!/usr/bin/env sh

set -o errexit
set -o nounset

# Doesn't follow symlinks, but it's likely expected for most users
SCRIPT_BASENAME="$(basename "${0}")"
SCRIPT_DIRECTORY_PATH="$(dirname "${0}")"

echo "This script (name: ${SCRIPT_BASENAME}, directory path: ${SCRIPT_DIRECTORY_PATH}) has been invoked with: ${0} $*"

# shellcheck source=/dev/null
. ../../../scripts/common.sh

WORKING_DIRECTORY="$(pwd)"
VIRTUAL_ENVIRONMENT_PATH="${WORKING_DIRECTORY}/.venv-smart-desk"

create_and_activate_python_virtual_environment "${VIRTUAL_ENVIRONMENT_PATH}" "${WORKING_DIRECTORY}/requirements.txt"

echo "Getting ESPHome version"
esphome --verbose version

ESPHOME_CONFIGURATION_FILE_NAME="smart-desk.yaml"
ESPHOME_NODE_NAME="smart-desk"

if [ ! -r secrets.yaml ]; then
  echo "No secrets file available. Creating one from the template..."
  cp -v secrets-template.yaml secrets.yaml
fi

echo "Validating ESPHome configuration..."
esphome --verbose config "${ESPHOME_CONFIGURATION_FILE_NAME}"

if [ "${CI:-}" = "true" ]; then
  echo "Continuous integration environment detected. Compiling the firmware without pushing it to the ESPHome node."
  esphome compile "${ESPHOME_CONFIGURATION_FILE_NAME}"
  compress_file ".esphome/build/${ESPHOME_NODE_NAME}/.pioenvs/${ESPHOME_NODE_NAME}/firmware-factory.bin"
else
  esphome run "${ESPHOME_CONFIGURATION_FILE_NAME}"
fi
