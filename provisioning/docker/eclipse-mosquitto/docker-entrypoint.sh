#!/bin/sh

set -e

IOT_CORE_PROJECT_ID="${1}" && shift
IOT_CORE_CREDENTIALS_VALIDITY="${1}" && shift
IOT_CORE_DEVICE_ID="${1}" && shift
IOT_CORE_DEVICE_NAME="${1}" && shift
COMMAND="${1}" && shift

COMMAND_PATH=
MQTT_TOPICS=

if [ "${COMMAND}" = "subscribe" ]; then
  COMMAND_PATH="mosquitto_sub"
  MQTT_TOPICS="${MQTT_TOPICS} --topic /devices/${IOT_CORE_DEVICE_NAME}/commands/#"
  MQTT_TOPICS="${MQTT_TOPICS} --topic /devices/${IOT_CORE_DEVICE_NAME}/config"
elif [ "${COMMAND}" = "publish" ]; then
  echo "Publishing a message..."
  COMMAND_PATH="mosquitto_pub"
  SUB_COMMAND="${1}" && shift
  SLEEP_AFTER_SENDING_MQTT_MESSAGE="${1}" && shift
  MQTT_MESSAGE_PAYLOAD_FILE_PATH=
  if [ -z "${SUB_COMMAND}" ]; then
    echo "Error: sub command not speficied. Terminating..."
    exit 1
  elif [ "${SUB_COMMAND}" = "telemetry-node-exporter" ]; then
    echo "Sending Prometheus Node Exporter data as a telemetry event..."
    MQTT_TOPICS="${MQTT_TOPICS} --topic /devices/${IOT_CORE_DEVICE_NAME}/events/node-exporter"

    echo "Starting Prometheus Node Exporter in background..."
    node_exporter &

    MQTT_MESSAGE_PAYLOAD_FILE_PATH="/tmp/prometheus-node-exporter-metrics.dat"
    echo "Saving metrics data to ${MQTT_MESSAGE_PAYLOAD_FILE_PATH}..."
    curl localhost:9100/metrics > "${MQTT_MESSAGE_PAYLOAD_FILE_PATH}"
  fi
fi

if [ -z "${COMMAND_PATH}" ] || [ -z "${MQTT_TOPICS}" ]; then
  echo "Error: command path (${COMMAND_PATH}) or MQTT topics list (${MQTT_TOPICS}) are empty. Terminating..."
  exit 1
fi

echo "Copying mosquitto configuration files where expected..."
MOSQUITTO_PUB_SUB_CONFIG_DIRECTORY_PATH="${HOME}"/.config
MOSQUITTO_PUB_SUB_CONFIG_SOURCE_DIRECTORY_PATH="/etc/mosquitto"
mkdir -p "${MOSQUITTO_PUB_SUB_CONFIG_DIRECTORY_PATH}"
cp "${MOSQUITTO_PUB_SUB_CONFIG_SOURCE_DIRECTORY_PATH}/"* "${MOSQUITTO_PUB_SUB_CONFIG_DIRECTORY_PATH}/"

echo "Generating JWT valid for ${IOT_CORE_PROJECT_ID} project and duration ${IOT_CORE_CREDENTIALS_VALIDITY} seconds from now..."
IOT_CORE_JWT="$(pyjwt --key="$(cat /etc/cloud-iot-core/keys/private_key.pem)" --alg=RS256 encode iat="$(date +%s)" exp=+"${IOT_CORE_CREDENTIALS_VALIDITY}" aud="${IOT_CORE_PROJECT_ID}")"

COMMAND_TO_RUN="${COMMAND_PATH} --id ${IOT_CORE_DEVICE_ID} --pw ${IOT_CORE_JWT} -W ${IOT_CORE_CREDENTIALS_VALIDITY} ${MQTT_TOPICS}"

if [ -n "${MQTT_MESSAGE_PAYLOAD_FILE_PATH}" ]; then
  echo "Found a path to a file to send as payload: ${MQTT_MESSAGE_PAYLOAD_FILE_PATH}"
  COMMAND_TO_RUN="${COMMAND_TO_RUN} --file ${MQTT_MESSAGE_PAYLOAD_FILE_PATH}"
fi

echo "Running command: ${COMMAND_TO_RUN}"
eval "${COMMAND_TO_RUN}" || exit 1

if [ -z "${SLEEP_AFTER_SENDING_MQTT_MESSAGE}" ]; then
  echo "Sleeping for: ${SLEEP_AFTER_SENDING_MQTT_MESSAGE}"
  sleep "${SLEEP_AFTER_SENDING_MQTT_MESSAGE}"
fi
