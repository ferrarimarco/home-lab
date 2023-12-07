#!/usr/bin/env sh

set -o errexit
set -o nounset

# shellcheck disable=SC1091,SC1094
. ./scripts/common.sh

echo "Running lint checks"

_DOCKER_INTERACTIVE_TTY_OPTION=
if [ -t 0 ]; then
  _DOCKER_INTERACTIVE_TTY_OPTION="-it"
fi

LINT_CI_JOB_PATH=".github/workflows/lint.yaml"
DEFAULT_LINTER_CONTAINER_IMAGE_VERSION="$(grep <"${LINT_CI_JOB_PATH}" "super-linter/super-linter" | awk -F '@' '{print $2}')"

LINTER_CONTAINER_IMAGE="ghcr.io/super-linter/super-linter:${LINTER_CONTAINER_IMAGE_VERSION:-${DEFAULT_LINTER_CONTAINER_IMAGE_VERSION}}"

echo "Running linter container image: ${LINTER_CONTAINER_IMAGE}"

# shellcheck disable=SC2086
docker run \
  ${_DOCKER_INTERACTIVE_TTY_OPTION} \
  --env ACTIONS_RUNNER_DEBUG="${ACTIONS_RUNNER_DEBUG:-"false"}" \
  --env MULTI_STATUS="false" \
  --env RUN_LOCAL="true" \
  --env-file "config/lint/super-linter.env" \
  --name "super-linter" \
  --rm \
  --volume "$(pwd)":/tmp/lint \
  --volume /etc/localtime:/etc/localtime:ro \
  --workdir /tmp/lint \
  "${LINTER_CONTAINER_IMAGE}" \
  "$@"

unset _DOCKER_INTERACTIVE_TTY_OPTION
