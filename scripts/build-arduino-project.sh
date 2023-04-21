#!/usr/bin/env sh

set -o errexit
set -o nounset

# Doesn't follow symlinks, but it's likely expected for most users
SCRIPT_BASENAME="$(basename "${0}")"
SCRIPT_DIRECTORY_PATH="$(dirname "${0}")"

echo "This script (name: ${SCRIPT_BASENAME}, directory path: ${SCRIPT_DIRECTORY_PATH}) has been invoked with: ${0} $*"

# shellcheck source=/dev/null
. "${SCRIPT_DIRECTORY_PATH}/common.sh"

WORKING_DIRECTORY="$(pwd)"

ARDUINO_CLI_CONTAINER_IMAGE_CONTEXT_PATH="docker/arduino-cli"
ARDUINO_CLI_CONTAINER_IMAGE_TAG="home-lab/arduino-cli:latest"

docker build \
  --tag "${ARDUINO_CLI_CONTAINER_IMAGE_TAG}" \
  "${ARDUINO_CLI_CONTAINER_IMAGE_CONTEXT_PATH}"
