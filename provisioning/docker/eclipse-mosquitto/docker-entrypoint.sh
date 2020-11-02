#!/bin/sh

set -e

IOT_CORE_PROJECT_ID="${1}" && shift
IOT_CORE_CREDENTIALS_VALIDITY="${1}" && shift
IOT_CORE_DEVICE_ID="${1}" && shift
IOT_CORE_DEVICE_NAME="${1}" && shift
COMMAND_PATH="${1}" && shift

echo "Generating JWT valid for ${IOT_CORE_PROJECT_ID} project and duration ${IOT_CORE_CREDENTIALS_VALIDITY} seconds from now..."
IOT_CORE_JWT="$(pyjwt --key="$(cat /etc/cloud-iot-core/keys/private_key.pem)" --alg=RS256 encode iat="$(date +%s)" exp=+"${IOT_CORE_CREDENTIALS_VALIDITY}" aud="${IOT_CORE_PROJECT_ID}")"

echo "Running ${COMMAND_PATH}. Device id: ${IOT_CORE_DEVICE_ID}, Device name: ${IOT_CORE_DEVICE_NAME}, MQTT timeout: ${IOT_CORE_CREDENTIALS_VALIDITY}"
eval "${COMMAND_PATH}" "--id ${IOT_CORE_DEVICE_ID}" "--pw ${IOT_CORE_JWT}" "-W ${IOT_CORE_CREDENTIALS_VALIDITY}" "--topic /devices/${IOT_CORE_DEVICE_NAME}/commands/#" "--topic /devices/${IOT_CORE_DEVICE_NAME}/config"
