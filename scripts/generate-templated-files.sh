#!/usr/bin/env sh

set -o errexit
set -o nounset

# Doesn't follow symlinks, but it's likely expected for most users
SCRIPT_BASENAME="$(basename "${0}")"

echo "This script (${SCRIPT_BASENAME}) has been invoked with: $0 $*"

TEMPLATE_RENDERER_CONTAINER_IMAGE_CONTEXT_PATH="docker/template-renderer"

docker build -t template-renderer "${TEMPLATE_RENDERER_CONTAINER_IMAGE_CONTEXT_PATH}"

SEED_DEVICE_CLOUD_INIT_DIRECTORY_PATH="config/cloud-init/seed-device"

echo "Building the seed device cloud-init configuration files in: ${SEED_DEVICE_CLOUD_INIT_DIRECTORY_PATH}"
docker run template-renderer render_template "cloud-init/meta-data.yaml.jinja" > "${SEED_DEVICE_CLOUD_INIT_DIRECTORY_PATH}/meta-data.yaml"
docker run template-renderer render_template "cloud-init/user-data.yaml.jinja" --template_data_file_paths "config/cloud-init/seed-device/ubuntu-20.04-autoinstall.yaml" > "${SEED_DEVICE_CLOUD_INIT_DIRECTORY_PATH}/user-data-autoinstall.yaml"
docker run template-renderer render_template "cloud-init/user-data.yaml.jinja" --template_data_file_paths "config/cloud-init/seed-device/ubuntu-20.04-autoinstall.yaml" "config/cloud-init/no-autoinstall.yaml" > "${SEED_DEVICE_CLOUD_INIT_DIRECTORY_PATH}/user-data.yaml"
