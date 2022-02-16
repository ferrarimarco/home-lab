#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

LC_ALL=C
export LC_ALL

# Ignoring SC2034 because this variable is used in other scripts
# shellcheck disable=SC2034
EXIT_OK=0
# Ignoring SC2034 because this variable is used in other scripts
# shellcheck disable=SC2034
ERR_GENERIC=1
ERR_VARIABLE_NOT_DEFINED=2
# Ignoring SC2034 because this variable is used in other scripts
# shellcheck disable=SC2034
ERR_MISSING_DEPENDENCY=3
# Ignoring SC2034 because this variable is used in other scripts
# shellcheck disable=SC2034
ERR_ARGUMENT_EVAL_ERROR=4
ERR_ARCHIVE_NOT_SUPPORTED=5

# Ignoring SC2034 because this variable is used in other scripts
# shellcheck disable=SC2034
BUILD_TYPE_CIDATA_ISO="cidata-iso"
# Ignoring SC2034 because this variable is used in other scripts
# shellcheck disable=SC2034
BUILD_TYPE_CUSTOMIZE_IMAGE="customize-image"

append_directory_contents() {
  SOURCE_DIRECTORY="${1}"
  DESTINATION_DIRECTORY="${2}"

  if [ ! -d "${SOURCE_DIRECTORY}" ]; then
    echo "[ERROR]: ${SOURCE_DIRECTORY} doesn't exist or it's not a directory."
    return ${ERR_ARGUMENT_EVAL_ERROR}
  fi
  if [ ! -e "${DESTINATION_DIRECTORY}" ]; then
    mkdir \
      --parents \
      --verbose
      "${DESTINATION_DIRECTORY}"
  fi

  echo "Appending ${SOURCE_DIRECTORY} contents to ${DESTINATION_DIRECTORY}"

  rsync \
    --archive \
    --verbose \
    "${SOURCE_DIRECTORY}/" \
    "${DESTINATION_DIRECTORY}/"

  unset SOURCE_DIRECTORY
  unset DESTINATION_DIRECTORY
}

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

print_or_warn() {
  FILE_PATH="${1}"
  PRINT_FILE_CONTENTS_IN_DIRECTORY="${2:-"false"}"
  if [ -e "${FILE_PATH}" ]; then
    echo "-------------------------"
    echo "Contents of ${FILE_PATH} ($(echo && ls -alhR "${FILE_PATH}")):"
    if [ -f "${FILE_PATH}" ]; then
      cat "${FILE_PATH}"
    fi
    echo "-------------------------"

    if [ "${PRINT_FILE_CONTENTS_IN_DIRECTORY}" = "true" ] && [ -d "${FILE_PATH}" ]; then
      echo "Contents of the files contained in the ${FILE_PATH} directory and its subdirectories:"
      find "${FILE_PATH}" -type f -print -exec echo \; -exec cat {} \; -exec echo \;
    fi
  else
    echo "${FILE_PATH} doesn't exist"
  fi
  unset FILE_PATH
  unset PRINT_FILE_CONTENTS
}

compress_file() {
  SOURCE_FILE_PATH="${1}"

  echo "Compressing ${SOURCE_FILE_PATH}..."
  xz -9 \
    --compress \
    --force \
    --threads=0 \
    --verbose \
    "${SOURCE_FILE_PATH}"

  COMPRESSED_FILE_PATH="${SOURCE_FILE_PATH}.xz"
  export COMPRESSED_FILE_PATH
}

copy_file_if_available() {
  SOURCE_FILE_PATH="${1}"
  DESTINATION_FILE_PATH="${2}"

  if [ -e "${SOURCE_FILE_PATH}" ]; then
    echo "Copying ${SOURCE_FILE_PATH} to ${DESTINATION_FILE_PATH}"
    cp \
      --force \
      --verbose \
      "${SOURCE_FILE_PATH}" "${DESTINATION_FILE_PATH}"
  fi

  unset SOURCE_FILE_PATH
  unset DESTINATION_FILE_PATH
}

decompress_file() {
  FILE_TO_DECOMPRESS_PATH="${1}"
  FILE_TO_DECOMPRESS_EXTENSION="${FILE_TO_DECOMPRESS_PATH##*.}"

  echo "Decompressing ${FILE_TO_DECOMPRESS_PATH} (file extension: ${FILE_TO_DECOMPRESS_EXTENSION})..."
  if [ "${FILE_TO_DECOMPRESS_EXTENSION}" = "xz" ]; then
    echo "Getting information about the ${IMAGE_ARCHIVE_FILE_PATH} archive: $(
      echo
      xz --list "${FILE_TO_DECOMPRESS_PATH}"
    )"
    xz \
      --decompress \
      --threads=0 \
      --verbose \
      "${FILE_TO_DECOMPRESS_PATH}"
  elif [ "${FILE_TO_DECOMPRESS_EXTENSION}" = "zip" ]; then
    echo "Getting information about the ${IMAGE_ARCHIVE_FILE_PATH} archive: $(
      echo
      unzip -v "${FILE_TO_DECOMPRESS_PATH}"
    )"
    unzip \
      -u \
      "${FILE_TO_DECOMPRESS_PATH}"
  else
    echo "${FILE_TO_DECOMPRESS_PATH} archive is not supported. Terminating..."
    return ${ERR_ARCHIVE_NOT_SUPPORTED}
  fi

  unset FILE_TO_DECOMPRESS_PATH
  unset FILE_TO_DECOMPRESS_EXTENSION
}

download_file_if_necessary() {
  FILE_TO_DOWNLOAD_URL="${1}"
  FILE_TO_DOWNLOAD_PATH="${2}"

  if [ ! -f "${FILE_TO_DOWNLOAD_PATH}" ]; then
    curl -L -o "${FILE_TO_DOWNLOAD_PATH}" "${FILE_TO_DOWNLOAD_URL}"
  else
    echo "${FILE_TO_DOWNLOAD_PATH} already exists. Skipping download of ${FILE_TO_DOWNLOAD_URL}"
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

initialize_resolv_conf() {
  RESOLV_CONF_PATH="${1}"
  RESOLV_CONF_DIRECTORY_PATH="$(dirname "${RESOLV_CONF_PATH}")"
  CUSTOMIZED_RESOLV_CONF="false"
  if [ ! -f "${RESOLV_CONF_PATH}" ]; then
    mkdir \
      --parents \
      --verbose \
      "${RESOLV_CONF_DIRECTORY_PATH}"
    printf "nameserver 8.8.8.8\nnameserver 8.8.4.4\n" >"${RESOLV_CONF_PATH}"
    CUSTOMIZED_RESOLV_CONF="true"
    export CUSTOMIZED_RESOLV_CONF
  fi

  print_or_warn "${RESOLV_CONF_PATH}"

  unset RESOLV_CONF_PATH
  unset RESOLV_CONF_DIRECTORY_PATH
}

register_qemu_static() {
  echo "Registering qemu-*-static for all supported processors except the current one..."
  # Keep the "--reset" option as the first because the register script consumes it before passing the rest to qemu-binfmt-conf.sh
  # See https://github.com/multiarch/qemu-user-static/blob/master/containers/latest/register.sh
  # The "|| true" is to ensure that this doesn't block the exeuction. There's an issue with when registering the hexagon binfmt
  # (and we don't need to emulate hexagon), so, adding this as a workaround.
  /register \
    --reset \
    --persistent yes ||
    true
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

  if [ "${UBUNTU_AUTOINSTALL}" = "true" ]; then
    USER_DATA_PATH="${CLOUD_INIT_DATASOURCE_CONFIG_DESTINATION_DIRECTORY}/user-data.yaml"
    USER_DATA_AUTOINSTALL_PATH="${CLOUD_INIT_DATASOURCE_CONFIG_DESTINATION_DIRECTORY}/user-data-autoinstall.yaml"
    echo "This build targets an instance that installs the OS with subiquity (Ubuntu autoinstaller)."
    if [ -e "${USER_DATA_AUTOINSTALL_PATH}" ]; then
      mv \
        --force \
        --verbose \
        "${USER_DATA_AUTOINSTALL_PATH}" "${USER_DATA_PATH}"
    fi
    unset USER_DATA_PATH
    unset USER_DATA_AUTOINSTALL_PATH
  fi

  echo "Removing the yaml file extension from cloud-init datasource configuration files..."
  for FILE in meta-data.yaml network-config.yaml vendor-data.yaml user-data.yaml; do
    FILE_PATH="${CLOUD_INIT_DATASOURCE_CONFIG_DESTINATION_DIRECTORY}/${FILE}"
    if [ -e "${FILE_PATH}" ]; then
      if [ "${FILE}" = "user-data.yaml" ]; then
        echo "Validating cloud-init user-data file (${FILE_PATH})..."
        cloud-init devel schema --config-file "${FILE_PATH}"
      fi
      mv --verbose "${FILE_PATH}" "${FILE_PATH%.*}"
    fi
  done
}
