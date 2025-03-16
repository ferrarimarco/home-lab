#!/usr/bin/env bash
# shellcheck disable=SC2029
# Disable SC2029 because intend to expand variables on the client
# that runs this script, not on the server

set -o errexit
set -o nounset
set -o pipefail

_SOURCE_HOST="${1}"
_SOURCE_DIRECTORY="${2}"
_TARGET_DIRECTORY="${3}"

echo "Copying ${_SOURCE_DIRECTORY}@${_SOURCE_HOST} to ${_TARGET_DIRECTORY}"

RSYNC_COMMAND="rsync --archive --inplace --partial --progress --stats --verbose"
if [ "${ENABLE_CHECKSUM:-"false"}" = "true" ]; then
  RSYNC_COMMAND="${RSYNC_COMMAND} --checksum"
fi
if [ "${ENABLE_DRY_RUN:-"false"}" = "true" ]; then
  RSYNC_COMMAND="${RSYNC_COMMAND} --dry-run"
fi
if [ "${ENABLE_WHOLE_FILE:-"false"}" = "true" ]; then
  RSYNC_COMMAND="${RSYNC_COMMAND} --whole-file"
fi
if [ -n "${RSYNC_PASSWORD_FILE_PATH:-""}" ]; then
  RSYNC_COMMAND="${RSYNC_COMMAND} --password-file ${RSYNC_PASSWORD_FILE_PATH}"
fi

RSYNC_COMMAND="${RSYNC_COMMAND} ${_SOURCE_DIRECTORY} ${_TARGET_DIRECTORY}"

echo "rsync command: ${RSYNC_COMMAND}"

ssh "${_SOURCE_HOST}" "${RSYNC_COMMAND}"
