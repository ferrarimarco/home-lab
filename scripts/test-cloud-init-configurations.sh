#!/usr/bin/env sh

set -o errexit
set -o nounset

# Doesn't follow symlinks, but it's likely expected for most users
SCRIPT_BASENAME="$(basename "${0}")"

echo "This script (${SCRIPT_BASENAME}) has been invoked with: $0 $*"

CONTAINER_NAME="cloud-init-test"
CLOUD_INIT_CONTAINER_IMAGE_TAG="cloud-init:latest"

CLOUD_INIT_CONTAINER_IMAGE_CONTEXT_PATH="docker/cloud-init"

docker build -t "${CLOUD_INIT_CONTAINER_IMAGE_TAG}" "${CLOUD_INIT_CONTAINER_IMAGE_CONTEXT_PATH}"

CLOUD_INIT_DATASOURCE_PATH="${1}"

docker run \
  -d \
  -it \
  --device=/dev/fuse \
  --name="${CONTAINER_NAME}" \
  --privileged \
  --rm \
  --tmpfs /tmp \
  --tmpfs /run \
  --tmpfs /run/lock \
  -v "${CLOUD_INIT_DATASOURCE_PATH}/meta-data.yaml":/etc/cloud/datasources/NoCloud/meta-data \
  -v "${CLOUD_INIT_DATASOURCE_PATH}/user-data.yaml":/etc/cloud/datasources/NoCloud/user-data \
  -v /lib/modules:/lib/modules:ro \
  "${CLOUD_INIT_CONTAINER_IMAGE_TAG}"
