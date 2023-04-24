#!/usr/bin/env sh

set -o errexit
set -o nounset

SCRIPT_DIRECTORY_PATH="$(dirname "${0}")"

# shellcheck source=/dev/null
. "${SCRIPT_DIRECTORY_PATH}/common.sh"

ARDUINO_CLI_CONTAINER_IMAGE_CONTEXT_PATH="docker/arduino-cli"
ARDUINO_CLI_CONTAINER_IMAGE_TAG="home-lab/arduino-cli:latest"

docker build \
  --tag "${ARDUINO_CLI_CONTAINER_IMAGE_TAG}" \
  "${ARDUINO_CLI_CONTAINER_IMAGE_CONTEXT_PATH}"

PROJECT_CONTEXT_PATH="${1}"
echo "Project context path: ${PROJECT_CONTEXT_PATH}"
