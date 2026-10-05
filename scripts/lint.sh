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

# A Git worktree holds only the working files: the repository metadata lives in
# the main repository, and the container needs it at the same absolute path.
# Ref: https://github.com/super-linter/super-linter/blob/main/docs/run-linter-locally.md
GIT_COMMON_DIR="$(git rev-parse --path-format=absolute --git-common-dir)"
GIT_WORKTREE_VOLUMES=()
if [ "${GIT_COMMON_DIR}" != "$(pwd)/.git" ]; then
  echo "Running from a Git worktree. Mounting the main repository metadata: ${GIT_COMMON_DIR}"
  GIT_WORKTREE_VOLUMES+=(--volume "${GIT_COMMON_DIR}:${GIT_COMMON_DIR}:ro")
fi

if [ "${LINTER_CONTAINER_LINT_COMMIT_MESSAGE:-}" == "true" ]; then
  echo "Validating the commit message from the standard input"

  # - Attach the standard input without a terminal to read the commit message.
  # - Mount the repository as read-only because the check only needs the
  #   commitlint configuration file.
  # - Don't set the container name to run this check while a lint run is in
  #   progress.
  COMMITLINT_COMMAND=(
    docker run
    --entrypoint commitlint
    --interactive
    --rm
    --volume "$(pwd)":/tmp/lint:ro
    ${GIT_WORKTREE_VOLUMES[@]+"${GIT_WORKTREE_VOLUMES[@]}"}
    --workdir /tmp/lint
    "${LINTER_CONTAINER_IMAGE}"
  )

  # Fail on warnings if the lint run does, to match its verdict
  if grep --quiet --line-regexp "ENABLE_COMMITLINT_STRICT_MODE=true" "config/lint/super-linter.env"; then
    COMMITLINT_COMMAND+=(--strict)
  fi

  echo "Commitlint command: ${COMMITLINT_COMMAND[*]}"
  "${COMMITLINT_COMMAND[@]}"
  exit 0
fi

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
  ${GIT_WORKTREE_VOLUMES[@]+"${GIT_WORKTREE_VOLUMES[@]}"}
  --volume /etc/localtime:/etc/localtime:ro
  --workdir /tmp/lint
  "${LINTER_CONTAINER_IMAGE}"
  "$@"
)

echo "Super-linter command: ${SUPER_LINTER_COMMAND[*]}"
"${SUPER_LINTER_COMMAND[@]}"
