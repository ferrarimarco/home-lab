#!/bin/env sh

echo "Starting the MQTT client..."

DOCKER_TTY_OPTION=
if [ -t 0 ]; then
  DOCKER_TTY_OPTION="-t"
fi

# shellcheck disable=SC2140
IOT_CORE_INITIALIZER_CONTAINER_IMAGE_ID="{{ key "edge/iot-core/initializer-container-image-id" }}"
IOT_CORE_INITIALIZER_CONTAINER_NAME="iot-core-initializer"
echo "Starting ${CONTAINER_NAME} container from the ${IOT_CORE_INITIALIZER_CONTAINER_IMAGE_ID} image..."
docker run ${DOCKER_TTY_OPTION} \
  -i \
  --name "${IOT_CORE_INITIALIZER_CONTAINER_NAME}" \
  --rm \
  "${IOT_CORE_INITIALIZER_CONTAINER_IMAGE_ID}"

# Assuming that the IoT Core device name is the hostname
IOT_CORE_DEVICE_NAME="$(hostname)"
echo "IoT Core device name: ${IOT_CORE_DEVICE_NAME}"

# shellcheck disable=SC2140
IOT_CORE_PROJECT_ID="{{ key "edge/iot-core/project-id" }}"
echo "IoT Core project id: ${IOT_CORE_PROJECT_ID}"

# shellcheck disable=SC2140
IOT_CORE_REGISTRY_ID="{{ key "edge/iot-core/registry-id" }}"
echo "IoT Core registry id: ${IOT_CORE_REGISTRY_ID}"

IOT_CORE_DEVICE_ID="${IOT_CORE_REGISTRY_ID}/devices/${IOT_CORE_DEVICE_NAME}"
echo "Setting IoT Core device id to ${IOT_CORE_DEVICE_ID}"

# shellcheck disable=SC2140
IOT_CORE_CREDENTIALS_VALIDITY="{{ key "edge/iot-core/credentials-validity" }}"

MQTT_SUB_CONTAINER_NAME="mqtt-client-iot-core-sub"
# shellcheck disable=SC2140
MQTT_CLIENT_CONTAINER_IMAGE_ID="{{ key "edge/iot-core/mosquitto/container-image-id" }}"
echo "Starting ${MQTT_SUB_CONTAINER_NAME} container with volumes from the ${IOT_CORE_INITIALIZER_CONTAINER_NAME} container from the ${MQTT_CLIENT_CONTAINER_IMAGE_ID} image..."
docker run ${DOCKER_TTY_OPTION} \
  -i \
  --name "${MQTT_SUB_CONTAINER_NAME}" \
  --restart always \
  --rm \
  --volumes-from "${IOT_CORE_INITIALIZER_CONTAINER_NAME}"
  "${MQTT_CLIENT_CONTAINER_IMAGE_ID}" \
  "${IOT_CORE_PROJECT_ID}" \
  "${IOT_CORE_CREDENTIALS_VALIDITY}" \
  "${IOT_CORE_DEVICE_ID}" \
  "${IOT_CORE_DEVICE_NAME}" \
  "${COMMAND_PATH}"
