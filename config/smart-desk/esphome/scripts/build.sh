#!/usr/bin/env sh

set -o errexit
set -o nounset

# Doesn't follow symlinks, but it's likely expected for most users
SCRIPT_BASENAME="$(basename "${0}")"

echo "This script (${SCRIPT_BASENAME}) has been invoked with: $0 $*"

# shellcheck source=/dev/null
. scripts/install-dependencies.sh

if [ ! -r secrets.yaml ]; then
  echo "No secrets file available. Creating one from the template..."
  cp -v secrets-template.yaml secrets.yaml
fi

echo "Validating ESPHome configuration..."
esphome --verbose config smart-desk.yaml

if [ "${CI:-}" = "true" ]; then
  echo "Continuous integration environment detected. Compiling the firmware without pushing it to the ESPHome node."
  esphome compile smart-desk.yaml
else
  esphome run smart-desk.yaml
fi
