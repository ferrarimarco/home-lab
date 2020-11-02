#!/bin/env sh

initialize_systemd_service() {
  SYSTEMD_SERVICE_NAME="${1}" && shift
  SYSTEMD_SERVICE_SCRIPT_PATH="${1}"

  if [ -z "${SYSTEMD_SERVICE_NAME}" ]; then
    echo "ERROR while initializing the ${SYSTEMD_SERVICE_NAME} service: The SYSTEMD_SERVICE_NAME variable is not set, or set to an empty string"
    exit 1
  fi

  SERVICE_FILE_PATH="/lib/systemd/system/${SYSTEMD_SERVICE_NAME}"

  echo "Setting ownership of ${SERVICE_FILE_PATH} to root..."
  chown -v root:root "${SERVICE_FILE_PATH}"

  echo "Setting ownership of ${SYSTEMD_SERVICE_SCRIPT_PATH}..."
  chown -v root:root "${SYSTEMD_SERVICE_SCRIPT_PATH}"

  echo "Enabling ${SYSTEMD_SERVICE_NAME} systemd service..."
  systemctl enable "${SYSTEMD_SERVICE_NAME}"

  unset SYSTEMD_SERVICE_NAME
  unset SERVICE_FILE_PATH
}

echo "Initializing systemd..."

initialize_systemd_service "init-iot-core.service" "/usr/local/bin/init-iot-core.sh"
initialize_systemd_service "start-mqtt-client.service" "/usr/local/bin/start-mqtt-client.sh"
