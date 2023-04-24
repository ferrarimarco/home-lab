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

ARDUINO_FQBN="${2}"
echo "Arduino FQBN: ${ARDUINO_FQBN}"

DOCKER_FLAGS=
if [ -t 0 ]; then
  DOCKER_FLAGS=-it
fi

_PROJECT_CONTEXT_DESTINATION_PATH="/workdir/${PROJECT_CONTEXT_PATH}"

echo "Compiling the ${PROJECT_CONTEXT_PATH} sketch for ${ARDUINO_FQBN}"
docker run \
  ${DOCKER_FLAGS} \
  --rm \
  --volume="/dev:/dev" \
  --volume="$(pwd)/${PROJECT_CONTEXT_PATH}:${_PROJECT_CONTEXT_DESTINATION_PATH}" \
  --workdir "${_PROJECT_CONTEXT_DESTINATION_PATH}" \
  "${ARDUINO_CLI_CONTAINER_IMAGE_TAG}" \
  "arduino-cli board list"

unset _PROJECT_CONTEXT_DESTINATION_PATH
