#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

# Doesn't follow symlinks, but it's likely expected for most users
SCRIPT_BASENAME="$(basename "${0}")"

echo "This script (${SCRIPT_BASENAME}) has been invoked with: $0 $*"

EXIT_OK=0
ERR_GENERIC=1
ERR_VARIABLE_NOT_DEFINED=2
ERR_MISSING_DEPENDENCY=3
ERR_ARGUMENT_EVAL_ERROR=4
ERR_ARCHIVE_NOT_SUPPORTED=5

BUILD_TYPE_CIDATA_ISO="cidata-iso"
BUILD_TYPE_PREINSTALLED="customize-preinstalled"

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

  echo "Compressing ${SOURCE_FILE_PATH}..."
  xz -9 \
    --compress \
    --force \
    --threads=0 \
    --verbose \
    "${SOURCE_FILE_PATH}"

  COMPRESSED_FILE_PATH="${SOURCE_FILE_PATH}.xz"
}

decompress_file() {
  FILE_TO_DECOMPRESS_PATH="${1}"

  FILE_TO_DECOMPRESS_EXTENSION="${FILE_TO_DECOMPRESS_PATH##*.}"

  echo "Decompressing ${FILE_TO_DECOMPRESS_PATH}..."
  if [ "${FILE_TO_DECOMPRESS_EXTENSION}" = "xz" ]; then
    xz -d -T0 -v "${FILE_TO_DECOMPRESS_PATH}"
  else
    echo "${IMAGE_ARCHIVE_FILE_PATH} archive is not supported. Terminating..."
    return ${ERR_ARCHIVE_NOT_SUPPORTED}
  fi
}

download_file_if_necessary() {
  FILE_TO_DOWNLOAD_URL="${1}"
  FILE_TO_DOWNLOAD_NAME="${2-}"

  if [ ! -f "${FILE_TO_DOWNLOAD_PATH-}" ]; then

    if [ -z "${FILE_TO_DOWNLOAD_NAME}" ]; then
      curl -L -O "${FILE_TO_DOWNLOAD_URL}"
    else
      curl -L -o "${FILE_TO_DOWNLOAD_NAME}" "${FILE_TO_DOWNLOAD_URL}"
    fi
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

setup_cloud_init_nocloud_datasource() {
  CLOUD_INIT_DATASOURCE_CONFIG_DIRECTORY="${1}"
  CLOUD_INIT_DATASOURCE_CONFIG_DESTINATION_DIRECTORY="${2}"

  echo "Copying contents of the cloud-init datasource configuration directory (${CLOUD_INIT_DATASOURCE_CONFIG_DIRECTORY}) to ${CLOUD_INIT_DATASOURCE_CONFIG_DESTINATION_DIRECTORY}..."
  cp \
    --force \
    --recursive \
    --verbose \
    "${CLOUD_INIT_DATASOURCE_CONFIG_DIRECTORY}/." "${CLOUD_INIT_DATASOURCE_CONFIG_DESTINATION_DIRECTORY}/"

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

BUILD_CONFIG_PARAMETER_DESCRIPTION="path to the build configuration file"

usage() {
  echo
  echo "${SCRIPT_BASENAME} - Build OS images."
  echo
  echo "USAGE"
  echo "  ${SCRIPT_BASENAME} [options]"
  echo
  echo "OPTIONS"
  echo "  -b | --build-config: ${BUILD_CONFIG_PARAMETER_DESCRIPTION}"
  echo "  -h | --help: show this help message and exit"
  echo
  echo "EXIT STATUS"
  echo
  echo "  ${EXIT_OK} on correct execution."
  echo "  ${ERR_GENERIC} when an error occurs, and there's no specific error code to handle it."
  echo "  ${ERR_VARIABLE_NOT_DEFINED} when a parameter or a variable is not defined, or empty."
  echo "  ${ERR_MISSING_DEPENDENCY} when a required dependency is missing."
  echo "  ${ERR_ARGUMENT_EVAL_ERROR} when there was an error while evaluating the program options."
  echo "  ${ERR_ARCHIVE_NOT_SUPPORTED} when the archive is not supported."
}

if ! TEMP="$(getopt -o b:h --long build-config:,help \
  -n 'build' -- "$@")"; then
  echo "Terminating..." >&2
  exit 1
fi
eval set -- "$TEMP"

BUILD_ENVIRONMENT_CONFIGURATION_FILE_PATH=

while true; do
  echo "Decoding parameter ${1}..."
  case "${1}" in
  -b | --build-config)
    BUILD_ENVIRONMENT_CONFIGURATION_FILE_PATH="${2}"
    shift 2
    ;;
  --)
    echo "No more parameters to decode"
    shift
    break
    ;;
  -h | --help | *)
    usage
    exit ${EXIT_OK}
    break
    ;;
  esac
done

check_argument "${BUILD_ENVIRONMENT_CONFIGURATION_FILE_PATH}" "${BUILD_CONFIG_PARAMETER_DESCRIPTION}"

WORKSPACE_DIRECTORY="$(pwd)"
echo "Working directory: ${WORKSPACE_DIRECTORY}"

echo "Loading the build environment configuration from ${BUILD_ENVIRONMENT_CONFIGURATION_FILE_PATH}..."
# shellcheck source=/dev/null
. "${BUILD_ENVIRONMENT_CONFIGURATION_FILE_PATH}"

TEMP_WORKING_DIRECTORY="$(mktemp -d)"
echo "Created a temporary working directory: ${TEMP_WORKING_DIRECTORY}"

DEVICE_CONFIG_DIRECTORY="$(dirname "${BUILD_ENVIRONMENT_CONFIGURATION_FILE_PATH}")"
echo "Device configuration directory: ${DEVICE_CONFIG_DIRECTORY}"

CLOUD_INIT_DATASOURCE_SOURCE_DIRECTORY_PATH="${DEVICE_CONFIG_DIRECTORY}/cloud-init"
echo "Cloud-init configuration directory: ${CLOUD_INIT_DATASOURCE_SOURCE_DIRECTORY_PATH}"

if [ -n "${OS_IMAGE_URL}" ]; then
  download_file_if_necessary "${OS_IMAGE_URL}"

  if [ -n "${OS_IMAGE_CHECKSUM_FILE_URL}" ]; then
    download_file_if_necessary "${OS_IMAGE_CHECKSUM_FILE_URL}"
    echo "Verifying the integrity of the downloaded files..."
    sha256sum --ignore-missing -c "$(basename "${OS_IMAGE_CHECKSUM_FILE_URL}")"
  fi
fi

if [ "${BUILD_TYPE}" = "${BUILD_TYPE_PREINSTALLED}" ]; then
  IMAGE_ARCHIVE_FILE_PATH="${WORKSPACE_DIRECTORY}"/"$(basename "${OS_IMAGE_URL}")"
  if ! decompress_file "${IMAGE_ARCHIVE_FILE_PATH}"; then
    RET_CODE=$?
    echo "Error while decompressing ${IMAGE_ARCHIVE_FILE_PATH}. Terminating..."
    exit ${RET_CODE}
  fi

  IMAGE_FILE_NAME="$(basename "${IMAGE_ARCHIVE_FILE_PATH}" ".${FILE_TO_DECOMPRESS_EXTENSION}")"
  IMAGE_FILE_PATH="${WORKSPACE_DIRECTORY}/${IMAGE_FILE_NAME}"

  echo "Currently used loop devices:"
  losetup --list

  echo "Checking if there are stale mounts to clean before mounting ${IMAGE_FILE_PATH}..."
  if losetup -O NAME,BACK-FILE | grep "${IMAGE_FILE_PATH}"; then
    echo "Cleaning stale mounts..."
    losetup -O NAME,BACK-FILE | grep "${IMAGE_FILE_PATH}" | awk '{ print $1 }' | xargs -l1 losetup -d
  else
    echo "There are no stale mounts to clean."
  fi

  echo "Mapping ${IMAGE_FILE_PATH} to loop devices..."
  kpartx -asv "${IMAGE_FILE_PATH}"

  echo "Currently used loop devices:"
  losetup --list

  LOOP_DEVICE_PATH="$(losetup -O NAME,BACK-FILE | grep "${IMAGE_FILE_PATH}" | awk '{ print $1 }')"
  LOOP_DEVICE_NAME="$(basename "${LOOP_DEVICE_PATH}")"
  LOOP_DEVICE_PARTITION_PREFIX=/dev/mapper/"${LOOP_DEVICE_NAME}"

  echo "Mounting partitions from ${LOOP_DEVICE_PATH} (prefix: ${LOOP_DEVICE_PARTITION_PREFIX})"
  mount -v "${LOOP_DEVICE_PARTITION_PREFIX}"p1 "${TEMP_WORKING_DIRECTORY}"

  setup_cloud_init_nocloud_datasource "${CLOUD_INIT_DATASOURCE_SOURCE_DIRECTORY_PATH}" "${TEMP_WORKING_DIRECTORY}"

  if [ -n "${KERNEL_CMDLINE_FILE_PATH}" ]; then
    echo "Customizing the Kernel command line..."
    cp \
      --force \
      --verbose \
      "${DEVICE_CONFIG_DIRECTORY}/${KERNEL_CMDLINE_FILE_PATH}" "${TEMP_WORKING_DIRECTORY}/cmdline.txt"
  fi

  echo "Synchronizing latest filesystem changes..."
  sync

  echo "Unmounting file systems..."
  umount -v "${TEMP_WORKING_DIRECTORY}"

  echo "Deleting loop devices where ${IMAGE_FILE_PATH} was mapped..."
  kpartx -svd "${IMAGE_FILE_PATH}"

  echo "Removing the ${LOOP_DEVICE_PATH} loop device..."
  rm -f "${LOOP_DEVICE_PATH}"

  echo "Adding the ${OS_IMAGE_FILE_TAG} tag to the image file..."
  IMAGE_FILE_EXTENSION=".${IMAGE_FILE_PATH##*.}"
  IMAGE_FILE_DIRECTORY_PATH="$(dirname -- "${IMAGE_FILE_PATH}")"
  IMAGE_FILE_NAME="$(basename -- "${IMAGE_FILE_PATH}" "${IMAGE_FILE_EXTENSION}")"
  echo "Image file path: ${IMAGE_FILE_PATH}. Image file directory: ${IMAGE_FILE_DIRECTORY_PATH}. Image file name: ${IMAGE_FILE_NAME}. Image file extension: ${IMAGE_FILE_EXTENSION}"

  TARGET_IMAGE_FILE_NAME="${IMAGE_FILE_NAME}"-"${OS_IMAGE_FILE_TAG}""${IMAGE_FILE_EXTENSION}"
  TARGET_IMAGE_FILE_PATH="${IMAGE_FILE_DIRECTORY_PATH}"/"${TARGET_IMAGE_FILE_NAME}"
  mv -v "${IMAGE_FILE_PATH}" "${TARGET_IMAGE_FILE_PATH}"
elif [ "${BUILD_TYPE}" = "${BUILD_TYPE_CIDATA_ISO}" ]; then
  setup_cloud_init_nocloud_datasource "${CLOUD_INIT_DATASOURCE_SOURCE_DIRECTORY_PATH}" "${TEMP_WORKING_DIRECTORY}"

  TARGET_IMAGE_FILE_NAME="cloud-init-datasource-${OS_IMAGE_FILE_TAG}.iso"
  TARGET_IMAGE_FILE_PATH="${WORKSPACE_DIRECTORY}/${TARGET_IMAGE_FILE_NAME}"
  generate_cidata_iso "${TEMP_WORKING_DIRECTORY}" "${TARGET_IMAGE_FILE_PATH}"
else
  echo "[ERROR]: Unsupported build type. Terminating..."
  exit ${ERR_ARGUMENT_EVAL_ERROR}
fi

compress_file "${TARGET_IMAGE_FILE_PATH}"
CUSTOMIZED_COMPRESSED_IMAGE_FILE_NAME="$(basename "${COMPRESSED_FILE_PATH}")"

# Store metadata about the customization process
BUILD_RESULTS_FILE_PATH="${WORKSPACE_DIRECTORY}/results.out"
echo "Saving build metadata to ${BUILD_RESULTS_FILE_PATH}..."
{
  echo "CUSTOMIZED_IMAGE_FILE_NAME=${TARGET_IMAGE_FILE_NAME}"
  echo "CUSTOMIZED_COMPRESSED_IMAGE_FILE_NAME=${CUSTOMIZED_COMPRESSED_IMAGE_FILE_NAME}"
} >>"${BUILD_RESULTS_FILE_PATH}"


echo "Contents of ${BUILD_RESULTS_FILE_PATH}:"
cat "${BUILD_RESULTS_FILE_PATH}"

echo "Deleting the temporary working directory (${TEMP_WORKING_DIRECTORY})..."
rm \
  --force \
  --recursive \
  "${TEMP_WORKING_DIRECTORY}"
