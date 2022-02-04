#!/usr/bin/env sh

set -o errexit
set -o nounset

# Doesn't follow symlinks, but it's likely expected for most users
SCRIPT_BASENAME="$(basename "${0}")"

echo "This script (${SCRIPT_BASENAME}) has been invoked with: $0 $*"

compress_file() {
  SOURCE_FILE_PATH="${1}"

  echo "Compressing ${SOURCE_FILE_PATH}..."
  xz -9 \
    --compress \
    --force \
    --threads=0 \
    --verbose \
    "${SOURCE_FILE_PATH}"
}

# shellcheck source=/dev/null
. scripts/install-dependencies.sh

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
  echo "PWD: $(pwd)"
  ls -alhR "config/smart-desk/esphome/.esphome/"
  compress_file "config/smart-desk/esphome/.esphome/build/${ESPHOME_NODE_NAME}/.pioenvs/${ESPHOME_NODE_NAME}/firmware-factory.bin"
else
  esphome run "${ESPHOME_CONFIGURATION_FILE_NAME}"
fi
