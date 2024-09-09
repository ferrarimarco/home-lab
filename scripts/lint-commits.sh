#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

# shellcheck disable=SC1091,SC1094
. ./scripts/common.sh

echo "Lint commits"

if [ -z "${FROM_INTERVAL_COMMITLINT:-}" ]; then
  FROM_INTERVAL_COMMITLINT="HEAD~1"
fi

if [ -z "${TO_INTERVAL_COMMITLINT:-}" ]; then
  TO_INTERVAL_COMMITLINT="HEAD"
fi

build_cd_container

LINT_COMMITS_COMMAND=(
  docker run
)

if [ -t 0 ]; then
  LINT_COMMITS_COMMAND+=(
    --interactive
    --tty
  )
fi

# shellcheck disable=SC2206
LINT_COMMITS_COMMAND+=(
  --rm
  --volume "$(pwd):/source-repository"
  "${CD_CONTAINER_URL}"
  commitlint
  --config config/lint/commitlint.config.js
  --cwd /source-repository
  --from ${FROM_INTERVAL_COMMITLINT}
  --to ${TO_INTERVAL_COMMITLINT}
  --verbose
)

echo "Lint commits command: ${LINT_COMMITS_COMMAND[*]}"
"${LINT_COMMITS_COMMAND[@]}"
