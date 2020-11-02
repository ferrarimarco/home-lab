#!/bin/sh

set -e

IOT_CORE_PROJECT_ID="${1}" && shift
IOT_CORE_CREDENTIALS_VALIDITY="${1}" && shift
IOT_CORE_DEVICE_ID="${1}" && shift
IOT_CORE_DEVICE_NAME="${1}" && shift
COMMAND_PATH="${1}" && shift

echo "Copying mosquitto configuration files where expected..."
MOSQUITTO_PUB_SUB_CONFIG_DIRECTORY_PATH="${HOME}"/.config
MOSQUITTO_PUB_SUB_CONFIG_SOURCE_DIRECTORY_PATH="/etc/mosquitto"
mkdir -p "${MOSQUITTO_PUB_SUB_CONFIG_DIRECTORY_PATH}"
cp "${MOSQUITTO_PUB_SUB_CONFIG_SOURCE_DIRECTORY_PATH}/*" "${MOSQUITTO_PUB_SUB_CONFIG_DIRECTORY_PATH}/"

echo "Generating JWT valid for ${IOT_CORE_PROJECT_ID} project and duration ${IOT_CORE_CREDENTIALS_VALIDITY} seconds from now..."
IOT_CORE_JWT="$(pyjwt --key="$(cat /etc/cloud-iot-core/keys/private_key.pem)" --alg=RS256 encode iat="$(date +%s)" exp=+"${IOT_CORE_CREDENTIALS_VALIDITY}" aud="${IOT_CORE_PROJECT_ID}")"

COMMAND_TO_RUN="${COMMAND_PATH} --id ${IOT_CORE_DEVICE_ID} --pw ${IOT_CORE_JWT} -W ${IOT_CORE_CREDENTIALS_VALIDITY} --topic /devices/${IOT_CORE_DEVICE_NAME}/commands/# --topic /devices/${IOT_CORE_DEVICE_NAME}/config"
echo "Running command: ${COMMAND_TO_RUN}"
eval "${COMMAND_TO_RUN}"
