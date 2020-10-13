#!/bin/sh

set -e

if [ ! -d "${IOT_CORE_CONFIGURATION_DIRECTORY_PATH}" ]; then
  echo "Creating ${IOT_CORE_CONFIGURATION_DIRECTORY_PATH}..."
  mkdir -p "${IOT_CORE_CONFIGURATION_DIRECTORY_PATH}"
fi

echo "Checking if IoT Core keys are initialized in ${IOT_CORE_KEYS_DIRECTORY_PATH}..."
if [ ! -f "${IOT_CORE_KEYS_PRIVATE_KEY_PATH}" ]; then
  echo "Initializing IoT Core keys..."

  echo "Creating ${IOT_CORE_KEYS_DIRECTORY_PATH}..."
  mkdir -p "${IOT_CORE_KEYS_DIRECTORY_PATH}"

  echo "Generating a private key: ${IOT_CORE_KEYS_PRIVATE_KEY_PATH}..."
  # shellcheck disable=SC2140
  openssl genpkey -algorithm RSA -out "${IOT_CORE_KEYS_PRIVATE_KEY_PATH}" -pkeyopt rsa_keygen_bits:"{{ key "edge/iot-core/rsa-key-length-bits" }}"

  echo "Cleaning up the old public key, if present"
  rm -f "${IOT_CORE_KEYS_PUBLIC_KEY_PATH}" || true

  echo "Generating a public key (${IOT_CORE_KEYS_PUBLIC_KEY_PATH}) from the ${IOT_CORE_KEYS_PRIVATE_KEY_PATH} private key..."
  openssl rsa -in "${IOT_CORE_KEYS_PRIVATE_KEY_PATH}" -pubout -out "${IOT_CORE_KEYS_PUBLIC_KEY_PATH}"
else
  echo "IoT Core keys are already initialized."
fi

echo "IoT Core keys public key file (${IOT_CORE_KEYS_PUBLIC_KEY_PATH}) contents: $(
  echo
  cat "${IOT_CORE_KEYS_PUBLIC_KEY_PATH}"
)"
