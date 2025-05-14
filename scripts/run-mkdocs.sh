#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

# shellcheck source=/dev/null
. "./scripts/common.sh"

# renovate: datasource=docker packageName=squidfunk/mkdocs-material versioning=docker
MKDOCS_CONTAINER_IMAGE_VERSION="9.6.14"
MKDOCS_CONTAINER_IMAGE="squidfunk/mkdocs-material:${MKDOCS_CONTAINER_IMAGE_VERSION}"

echo "Running mkdocs: ${MKDOCS_CONTAINER_IMAGE}"

SUBCOMMAND="${1}"
echo "Subcommand: ${SUBCOMMAND}"

MKDOCS_CONFIG_FILE_DIRECTORY_NAME="${2}"
echo "Mkdocs config file directory name: ${MKDOCS_CONFIG_FILE_DIRECTORY_NAME}"

RUN_CONTAINER_COMMAND=(
  docker run
  --rm
)

if [ -t 0 ]; then
  RUN_CONTAINER_COMMAND+=(
    --interactive
    --tty
  )
fi

RUN_CONTAINER_COMMAND+=(
  --name "mkdocs"
  --publish "8000:8000"
  --volume "$(pwd)":/docs
  --volume /etc/localtime:/etc/localtime:ro
  "${MKDOCS_CONTAINER_IMAGE}"
)

MKDOCS_CONFIG_FILE_PATH="config/mkdocs/${MKDOCS_CONFIG_FILE_DIRECTORY_NAME}/mkdocs.yaml"
if [[ ! -f "${MKDOCS_CONFIG_FILE_PATH}" ]]; then
  echo "Mkdocs config file (${MKDOCS_CONFIG_FILE_PATH}) doesn't exist or is not readable"
  exit "${ERR_ARGUMENT_EVAL}"
fi

DEFAULT_MKDOCS_ARGS=(
  --config-file "${MKDOCS_CONFIG_FILE_PATH}"
)

if [[ "${SUBCOMMAND}" == "serve" ]]; then
  RUN_CONTAINER_COMMAND+=(
    "serve"
    "--dev-addr=0.0.0.0:8000"
    "${DEFAULT_MKDOCS_ARGS[@]}"
  )
elif [[ "${SUBCOMMAND}" == "build" ]]; then
  RUN_CONTAINER_COMMAND+=(
    "build"
    "--strict"
    "${DEFAULT_MKDOCS_ARGS[@]}"
  )
elif [[ "${SUBCOMMAND}" == "create" ]]; then
  RUN_CONTAINER_COMMAND+=(
    "new"
    .
  )
else
  echo "Set a mkdocs subcommand using the first argument"
  exit "${ERR_ARGUMENT_EVAL}"
fi

echo "Run container command: ${RUN_CONTAINER_COMMAND[*]}"
"${RUN_CONTAINER_COMMAND[@]}"
