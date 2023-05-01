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

_COMMAND_TO_RUN="arduino-cli compile --fqbn ${ARDUINO_FQBN}"

ARDUINO_BOARD_PORT="${3:-""}"

if [ -n "${ARDUINO_BOARD_PORT}" ]; then

  if [ ! -e "${ARDUINO_BOARD_PORT}" ]; then
    echo "[ERROR] ${ARDUINO_BOARD_PORT} is not available."
    # Ignoring because those are defined in common.sh, and don't need quotes
    # shellcheck disable=SC2086
    exit ${ERR_ARGUMENT_EVAL}
  fi

  if [ "${ARDUINO_UPLOAD:-"true"}" = "true" ]; then
    echo "Enabling the upload of the ${PROJECT_CONTEXT_PATH} sketch to ${ARDUINO_FQBN} (${ARDUINO_BOARD_PORT})"
    _COMMAND_TO_RUN="${_COMMAND_TO_RUN} && arduino-cli upload --discovery-timeout 30s --fqbn ${ARDUINO_FQBN} --port ${ARDUINO_BOARD_PORT}"
  fi

  if [ "${ARDUINO_MONITOR:-""}" = "true" ]; then
    echo "Enabling the monitoring of ${ARDUINO_FQBN} (${ARDUINO_BOARD_PORT})"
    _COMMAND_TO_RUN="${_COMMAND_TO_RUN} && arduino-cli monitor --discovery-timeout 30s --fqbn ${ARDUINO_FQBN} --port ${ARDUINO_BOARD_PORT}"
  fi
fi

echo "Running: ${_COMMAND_TO_RUN}"
docker run \
  ${DOCKER_FLAGS} \
  --rm \
  --volume="/dev:/dev" \
  --volume="$(pwd)/${PROJECT_CONTEXT_PATH}:${_PROJECT_CONTEXT_DESTINATION_PATH}" \
  --workdir "${_PROJECT_CONTEXT_DESTINATION_PATH}" \
  "${ARDUINO_CLI_CONTAINER_IMAGE_TAG}" \
  "${_COMMAND_TO_RUN}"

unset _COMMAND_TO_RUN
unset _PROJECT_CONTEXT_DESTINATION_PATH
unset ARDUINO_BOARD_PORT
unset ARDUINO_MONITOR
