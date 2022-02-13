#!/usr/bin/env sh

set -o errexit
set -o nounset

# Doesn't follow symlinks, but it's likely expected for most users
SCRIPT_BASENAME="$(basename "${0}")"

echo "This script (${SCRIPT_BASENAME}) has been invoked with: $0 $*"

TEMP_WORKSPACE_PATH="${TEMP_WORKSPACE_PATH:-"$(mktemp -d)"}"
echo "Temporary workspace path: ${TEMP_WORKSPACE_PATH}"

echo "Build configuration file path: ${BUILD_CONFIGURATION_FILE_PATH}"

BUILD_CONFIGURATION_FILE_NAME="$(basename "${BUILD_CONFIGURATION_FILE_PATH}")"
echo "Build configuration file name: ${BUILD_CONFIGURATION_FILE_NAME}"
BUILD_CONFIGURATION_DIRECTORY_PATH="$(dirname "${BUILD_CONFIGURATION_FILE_PATH}")"
echo "Build configuration directory path: ${BUILD_CONFIGURATION_DIRECTORY_PATH}"

OS_BUILDER_CONTAINER_IMAGE_ID="${OS_BUILDER_CONTAINER_IMAGE_ID:-"ferrarimarco/os-image-builder:latest"}"
echo "OS Builder container image id: ${OS_BUILDER_CONTAINER_IMAGE_ID}"

INTERACTIVE=$([ -t 0 ] && echo 1 || echo 0)
if [ "${INTERACTIVE}" = "1" ]; then
  DOCKER_FLAGS=-it
fi

docker run \
  ${DOCKER_FLAGS} \
  --privileged \
  --rm \
  -v /dev:/dev \
  -v "${TEMP_WORKSPACE_PATH}":/tmp/workdir \
  -v "${BUILD_CONFIGURATION_DIRECTORY_PATH}":/tmp/config \
  "${OS_BUILDER_CONTAINER_IMAGE_ID}" \
  --build-config /tmp/config/"${BUILD_CONFIGURATION_FILE_NAME}"

echo "Fixing the ownership of files and folders in ${TEMP_WORKSPACE_PATH}"
sudo chown \
  --recursive \
  --verbose \
  "$(id -u):$(id -g)" \
  "${TEMP_WORKSPACE_PATH}"

echo "Contents of ${TEMP_WORKSPACE_PATH}:"
ls -alh "${TEMP_WORKSPACE_PATH}"

RESULTS_FILE_PATH="${RESULTS_FILE_PATH:-"${TEMP_WORKSPACE_PATH}/results.out"}"
if ! [ -r "${RESULTS_FILE_PATH}" ]; then
  echo "[ERROR]: The build result metadata file is not readable at ${RESULTS_FILE_PATH}. Terminating..."
  exit 1
fi

echo "Sourcing ${RESULTS_FILE_PATH} to load the variables defined there..."
# shellcheck source=/dev/null
. "${RESULTS_FILE_PATH}"

CUSTOMIZED_COMPRESSED_IMAGE_FILE_PATH="${TEMP_WORKSPACE_PATH}/${CUSTOMIZED_COMPRESSED_IMAGE_FILE_NAME}"
if ! [ -e "${CUSTOMIZED_COMPRESSED_IMAGE_FILE_PATH}" ]; then
  echo "[ERROR]: The customized compressed image file (${CUSTOMIZED_COMPRESSED_IMAGE_FILE_PATH}) doesn't exist. Terminating..."
  exit 2
fi

echo "Adding environment variables to the build results file (${RESULTS_FILE_PATH})"
{
  echo "BUILD_CONFIGURATION_DIRECTORY_PATH=${BUILD_CONFIGURATION_DIRECTORY_PATH}"
  echo "BUILD_CONFIGURATION_FILE_NAME=${BUILD_CONFIGURATION_FILE_NAME}"
  echo "CUSTOMIZED_COMPRESSED_IMAGE_FILE_PATH=${CUSTOMIZED_COMPRESSED_IMAGE_FILE_PATH}"
  echo "RESULTS_FILE_PATH=${RESULTS_FILE_PATH}"
  echo "TEMP_WORKSPACE_PATH=${TEMP_WORKSPACE_PATH}"
} >>"${RESULTS_FILE_PATH}"

echo "Contents of the build results file path (${RESULTS_FILE_PATH}):"
cat "${RESULTS_FILE_PATH}"
