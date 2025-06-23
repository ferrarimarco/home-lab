#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

# shellcheck source=/dev/null
. "./scripts/common.sh"

# renovate: datasource=docker packageName=squidfunk/mkdocs-material versioning=docker
MKDOCS_CONTAINER_IMAGE_VERSION="9.6.14"
MKDOCS_CONTAINER_IMAGE="squidfunk/mkdocs-material:${MKDOCS_CONTAINER_IMAGE_VERSION}"

SCRIPT_DIRECTORY_PATH=$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")
echo "Script directory path: ${SCRIPT_DIRECTORY_PATH}"

echo "Running mkdocs: ${MKDOCS_CONTAINER_IMAGE}"

SUBCOMMAND="${1}"
echo "Subcommand: ${SUBCOMMAND}"
shift 1

MKDOCS_CONFIG_FILE_DIRECTORY_NAME="${1}"
echo "Mkdocs config file directory name: ${MKDOCS_CONFIG_FILE_DIRECTORY_NAME}"
shift 1

MKDOCS_SOURCE_DIRECTORY_PATH="${1}"
echo "Mkdocs source directory path: ${MKDOCS_SOURCE_DIRECTORY_PATH}"
shift 1

MKDOCS_DESTINATION_DIRECTORY_PATH="${1}"
echo "Mkdocs destination directory path: ${MKDOCS_CONFIG_FILE_DIRECTORY_NAME}"

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

if ! MKDOCS_CONFIG_FILE_PATH="$(readlink -f "${SCRIPT_DIRECTORY_PATH}/..")/config/mkdocs/${MKDOCS_CONFIG_FILE_DIRECTORY_NAME}/mkdocs.yaml"; then
  echo "Error while initializing MKDOCS_CONFIG_FILE_PATH"
fi
echo "Mkdocs config file path: ${MKDOCS_CONFIG_FILE_PATH}"
if [[ ! -f "${MKDOCS_CONFIG_FILE_PATH}" ]]; then
  echo "Mkdocs config file (${MKDOCS_CONFIG_FILE_PATH}) doesn't exist or is not readable"
  exit "${ERR_ARGUMENT_EVAL}"
fi

MKDOCS_CONFIG_FILE_DESTINATION_PATH="/config/mkdocs.yaml"

RUN_CONTAINER_COMMAND+=(
  --name "mkdocs"
  --publish "8000:8000"
  --volume "${MKDOCS_CONFIG_FILE_PATH}":"${MKDOCS_CONFIG_FILE_DESTINATION_PATH}"
  --volume "${MKDOCS_SOURCE_DIRECTORY_PATH}":/docs
  --volume "${MKDOCS_DESTINATION_DIRECTORY_PATH}":/dest
  --volume /etc/localtime:/etc/localtime:ro
  "${MKDOCS_CONTAINER_IMAGE}"
)

DEFAULT_MKDOCS_ARGS=(
  --config-file "${MKDOCS_CONFIG_FILE_DESTINATION_PATH}"
)

if [[ "${SUBCOMMAND}" == "serve" ]]; then
  RUN_CONTAINER_COMMAND+=(
    "serve"
    "--dev-addr=0.0.0.0:8000"
    "--strict"
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

# Check if changed files only include files that we can ignore, such as
# when only updating the sitemap
if check_if_uncommitted_files_only_include_files_to_ignore; then
  echo "Documentation commit only contains files to ignore. Checking them out from the Git repository to avoid unnecessary site publishing"
  git checkout "${MKDOCS_DESTINATION_DIRECTORY_PATH}"
fi
