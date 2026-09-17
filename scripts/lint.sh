#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

# shellcheck disable=SC1091,SC1094
. ./scripts/common.sh

echo "Running lint checks"

check_format_script_fixer_coverage || exit "${ERR_FORMAT_SCRIPT_FIXER_COVERAGE}"

LINTER_CONTAINER_IMAGE="$(get_super_linter_container_image)"

echo "Running linter container image: ${LINTER_CONTAINER_IMAGE}"

SUPER_LINTER_COMMAND=(
  docker run
)

if [ -t 0 ]; then
  SUPER_LINTER_COMMAND+=(
    --interactive
    --tty
  )
fi

if [ "${LINTER_CONTAINER_OPEN_SHELL:-}" == "true" ]; then
  SUPER_LINTER_COMMAND+=(
    --entrypoint "/bin/bash"
  )
fi

if [ "${LINTER_CONTAINER_FIX_MODE:-}" == "true" ]; then
  SUPER_LINTER_COMMAND+=(
    --env-file "config/lint/super-linter-fix-mode.env"
  )
fi

SUPER_LINTER_COMMAND+=(
  --env LOG_LEVEL="${LOG_LEVEL:-"INFO"}"
  --env MULTI_STATUS="false"
  --env RUN_LOCAL="true"
  --env-file "config/lint/super-linter.env"
  --name "super-linter"
  --rm
  --volume "$(pwd)":/tmp/lint
  --volume /etc/localtime:/etc/localtime:ro
  --workdir /tmp/lint
  "${LINTER_CONTAINER_IMAGE}"
  "$@"
)

echo "Super-linter command: ${SUPER_LINTER_COMMAND[*]}"
"${SUPER_LINTER_COMMAND[@]}"
