#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

# Ignoring SC2034 because this variable is used in other scripts
# shellcheck disable=SC2034
EXIT_OK=0

# Ignoring SC2034 because this variable is used in other scripts
# shellcheck disable=SC2034
ERR_GENERIC=1
# Ignoring SC2034 because this variable is used in other scripts
# shellcheck disable=SC2034
ERR_VARIABLE_NOT_DEFINED=2
# Ignoring SC2034 because this variable is used in other scripts
# shellcheck disable=SC2034
ERR_MISSING_DEPENDENCY=3
# Ignoring SC2034 because this variable is used in other scripts
# shellcheck disable=SC2034
ERR_ARGUMENT_EVAL_ERROR=4
# Ignoring SC2034 because this variable is used in other scripts
# shellcheck disable=SC2034
ERR_ARCHIVE_NOT_SUPPORTED=5

# Ignoring SC2034 because this variable is used in other scripts
# shellcheck disable=SC2034
HELP_DESCRIPTION="show this help message and exit"

check_argument() {
  ARGUMENT_VALUE="${1}"
  ARGUMENT_DESCRIPTION="${2}"

  if [ -z "${ARGUMENT_VALUE}" ]; then
    echo "[ERROR]: ${ARGUMENT_DESCRIPTION} is not defined. Run this command with the -h option to get help. Terminating..."
    exit ${ERR_VARIABLE_NOT_DEFINED}
  else
    echo "[OK]: ${ARGUMENT_DESCRIPTION} value is defined: ${ARGUMENT_VALUE}"
  fi

  unset ARGUMENT_NAME
  unset ARGUMENT_VALUE
}

compress_file() {
  SOURCE_FILE_PATH="${1}"
  DESTINATION_FILE_PATH="${2}"
  echo "Removing leftovers (${DESTINATION_FILE_PATH})..."
  rm -f "${DESTINATION_FILE_PATH}"

  echo "Compressing ${SOURCE_FILE_PATH}..."
  xz -9 \
    --compress \
    --threads=0 \
    --verbose \
    "${SOURCE_FILE_PATH}"
}

copy_file_if_exists() {
  SOURCE_FILE_PATH="${1}"
  DESTINATION_FILE_PATH="${2}"
  if [ -e "${SOURCE_FILE_PATH}" ]; then
    cp \
      --force \
      --verbose \
      "${SOURCE_FILE_PATH}" "${DESTINATION_FILE_PATH}"
  else
    echo "Source file ${SOURCE_FILE_PATH} doesn't exist."
  fi
}

# We don't use cloud-localds here because it doesn't support adding data to the
# ISO, besides user-data, network-config, vendor-data
generate_cidata_iso() {
  TEMP_CLOUD_INIT_WORKING_DIRECTORY="${1}"
  CLOUD_INIT_DATASOURCE_ISO_PATH="${2}"

  echo "Removing the eventual leftovers (${CLOUD_INIT_DATASOURCE_ISO_PATH}) from previous runs..."
  rm -f "${CLOUD_INIT_DATASOURCE_ISO_PATH}"

  echo "Generating the CIDATA ISO (${CLOUD_INIT_DATASOURCE_ISO_PATH} from ${TEMP_CLOUD_INIT_WORKING_DIRECTORY}..."
  genisoimage \
    -joliet \
    -output "${CLOUD_INIT_DATASOURCE_ISO_PATH}" \
    -rock \
    -verbose \
    -volid cidata \
    "${TEMP_CLOUD_INIT_WORKING_DIRECTORY}"
}

setup_cloud_init_nocloud_datasource() {
  CLOUD_INIT_DATASOURCE_CONFIG_DIRECTORY="${1}"
  CLOUD_INIT_DATASOURCE_CONFIG_DESTINATION_DIRECTORY="${2}"

  echo "Copying contents of the cloud-init datasource configuration directory (${CLOUD_INIT_DATASOURCE_CONFIG_DIRECTORY}) to ${CLOUD_INIT_DATASOURCE_CONFIG_DESTINATION_DIRECTORY}..."
  cp \
    --force \
    --recursive \
    --verbose \
    "${CLOUD_INIT_DATASOURCE_CONFIG_DIRECTORY}/." "${CLOUD_INIT_DATASOURCE_CONFIG_DESTINATION_DIRECTORY}/"

  CLOUD_INIT_USER_DATA_FILE_PATH="${CLOUD_INIT_DATASOURCE_CONFIG_DESTINATION_DIRECTORY}/user-data.yaml"
  echo "Validating cloud-init user-data file (${CLOUD_INIT_USER_DATA_FILE_PATH})..."
  cloud-init devel schema --config-file "${CLOUD_INIT_DATASOURCE_CONFIG_DESTINATION_DIRECTORY}/user-data.yaml"

  echo "Removing the yaml file extension from cloud-init datasource configuration files..."
  [ -e "${CLOUD_INIT_DATASOURCE_CONFIG_DESTINATION_DIRECTORY}"/meta-data.yaml ] && mv --verbose "${CLOUD_INIT_DATASOURCE_CONFIG_DESTINATION_DIRECTORY}"/meta-data.yaml "${CLOUD_INIT_DATASOURCE_CONFIG_DESTINATION_DIRECTORY}"/meta-data
  [ -e "${CLOUD_INIT_DATASOURCE_CONFIG_DESTINATION_DIRECTORY}"/network-config.yaml ] && mv --verbose "${CLOUD_INIT_DATASOURCE_CONFIG_DESTINATION_DIRECTORY}"/network-config.yaml "${CLOUD_INIT_DATASOURCE_CONFIG_DESTINATION_DIRECTORY}"/network-config
  [ -e "${CLOUD_INIT_USER_DATA_FILE_PATH}" ] && mv --verbose "${CLOUD_INIT_USER_DATA_FILE_PATH}" "${CLOUD_INIT_DATASOURCE_CONFIG_DESTINATION_DIRECTORY}"/user-data
  [ -e "${CLOUD_INIT_DATASOURCE_CONFIG_DESTINATION_DIRECTORY}"/vendor-data.yaml ] && mv --verbose "${CLOUD_INIT_DATASOURCE_CONFIG_DESTINATION_DIRECTORY}"/vendor-data.yaml "${CLOUD_INIT_DATASOURCE_CONFIG_DESTINATION_DIRECTORY}"/vendor-data
}
