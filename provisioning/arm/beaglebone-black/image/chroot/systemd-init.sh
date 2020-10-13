#!/bin/env sh

echo "Initializing systemd..."

IOT_CORE_INIT_SERVICE_NAME="init-iot-core.service"
IOT_CORE_INIT_SERVICE_PATH="/lib/systemd/system/${IOT_CORE_INIT_SERVICE_NAME}"

echo "Setting ownership of ${IOT_CORE_INIT_SERVICE_PATH}..."
chown -v root:root "${IOT_CORE_INIT_SERVICE_PATH}"

IOT_CORE_INIT_SERVICE_SCRIPT_PATH="/usr/local/bin/init-iot-core.sh"
echo "Setting ownership of ${IOT_CORE_INIT_SERVICE_SCRIPT_PATH}..."
chown -v root:root "${IOT_CORE_INIT_SERVICE_SCRIPT_PATH}"

echo "Enabling ${IOT_CORE_INIT_SERVICE_NAME} systemd service..."
systemctl enable "${IOT_CORE_INIT_SERVICE_NAME}"

START_MQTT_SERVICE_NAME="start-mqtt-client.service"
echo "Enabling ${START_MQTT_SERVICE_NAME} systemd service..."
systemctl enable "${START_MQTT_SERVICE_NAME}"
