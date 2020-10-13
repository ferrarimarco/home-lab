#!/bin/env sh

set -e

DOCKER_TTY_OPTION=
if [ -t 0 ]; then
  DOCKER_TTY_OPTION="-t"
fi

# shellcheck disable=SC2140
IOT_CORE_INITIALIZER_CONTAINER_IMAGE_ID="{{ key "edge/iot-core/initializer-container-image-id" }}"

IOT_CORE_INITIALIZER_CONTAINER_NAME="iot-core-initializer"
export IOT_CORE_INITIALIZER_CONTAINER_NAME
echo "Starting ${CONTAINER_NAME} container from the ${IOT_CORE_INITIALIZER_CONTAINER_IMAGE_ID} image..."
docker run ${DOCKER_TTY_OPTION} \
  -i \
  --name "${IOT_CORE_INITIALIZER_CONTAINER_NAME}" \
  --rm \
  "${IOT_CORE_INITIALIZER_CONTAINER_IMAGE_ID}"
