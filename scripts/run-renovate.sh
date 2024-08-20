#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

# shellcheck disable=SC1091,SC1094
. ./scripts/common.sh

echo "Run renovate"

# renovate: datasource=docker packageName=renovate/renovate versioning=docker
DEFAULT_RENOVATE_CONTAINER_IMAGE_VERSION="38.44.3"

RENOVATE_CONTAINER_IMAGE="renovate/renovate:${RENOVATE_CONTAINER_IMAGE_VERSION:-${DEFAULT_RENOVATE_CONTAINER_IMAGE_VERSION}}"

RENOVATE_COMMAND=(
  docker run
)

if [ -t 0 ]; then
  RENOVATE_COMMAND+=(
    --interactive
    --tty
  )
fi

check_github_token_file

RENOVATE_CONFIG_FILE="$(pwd)/.github/renovate-global-config.js"

RENOVATE_COMMAND+=(
  --env LOG_LEVEL="debug"
  --env LOG_FORMAT="json"
  --env RENOVATE_CONFIG_FILE="${RENOVATE_CONFIG_FILE}"
  --env RENOVATE_TOKEN="$(cat "${GITHUB_TOKEN_PATH}")"
  --volume "${RENOVATE_CONFIG_FILE}":"${RENOVATE_CONFIG_FILE}"
  "${RENOVATE_CONTAINER_IMAGE}"
  renovate
  --dry-run="full"
)

"${RENOVATE_COMMAND[@]}" | tee renovate.log.jsonl
