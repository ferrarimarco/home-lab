#!/usr/bin/env sh

set -o errexit
set -o nounset

# Doesn't follow symlinks, but it's likely expected for most users
SCRIPT_BASENAME="$(basename "${0}")"

echo "This script (${SCRIPT_BASENAME}) has been invoked with: $0 $*"

# shellcheck source=/dev/null
. scripts/install-dependencies.sh

esphome --verbose config smart-desk.yaml

if [ ! "${CI:-}" = "true" ]; then
  cp -v secrets-template.yaml secrets.yaml
  esphome run smart-desk.yaml
else
  echo "Continuous integration environment detected. Compiling the firmware without pushing it to the ESPHome node."
  esphome compile smart-desk.yaml
fi
