#!/usr/bin/env sh
# shellcheck disable=SC2029
# Disable SC2029 because intend to expand variables on the client
# that runs this script, not on the server

set -o errexit
set -o nounset

_SOURCE_HOST="${1}"
_SOURCE_DIRECTORY="${2}"
_TARGET_HOST="${3}"
_TARGET_DIRECTORY="${4}"

_SOURCE_DIRECTORY_DIRNAME="$(dirname "${_SOURCE_DIRECTORY}")"
_SOURCE_DIRECTORY_BASENAME="$(basename "${_SOURCE_DIRECTORY}")"

_ARCHIVE_FILE_NAME="${_SOURCE_DIRECTORY_BASENAME}-$(date '+%Y-%m-%d').tar.gz"

echo "Creating an archive (${_ARCHIVE_FILE_NAME}) of ${_SOURCE_HOST}:${_SOURCE_DIRECTORY}. Dirname: ${_SOURCE_DIRECTORY_DIRNAME}, basename: ${_SOURCE_DIRECTORY_BASENAME}"
ssh "${_SOURCE_HOST}" "sudo tar -czvf ${_ARCHIVE_FILE_NAME} -C ${_SOURCE_DIRECTORY_DIRNAME}/ ${_SOURCE_DIRECTORY_BASENAME}"

echo "Copying ${_ARCHIVE_FILE_NAME} to ${_TARGET_HOST}"
ssh "${_SOURCE_HOST}" "scp -C ${_ARCHIVE_FILE_NAME} ${_TARGET_HOST}:${_ARCHIVE_FILE_NAME}"

echo "Deleting ${_ARCHIVE_FILE_NAME} file from ${_SOURCE_HOST}"
ssh "${_SOURCE_HOST}" "rm -v ${_ARCHIVE_FILE_NAME}"

echo "Extracting ${_ARCHIVE_FILE_NAME} to ${_TARGET_HOST}:${_TARGET_DIRECTORY}"
ssh "${_TARGET_HOST}" "sudo tar --same-owner -xvf ${_ARCHIVE_FILE_NAME} --directory ${_TARGET_DIRECTORY}"

echo "Deleting ${_ARCHIVE_FILE_NAME} file from ${_TARGET_HOST}"
ssh "${_TARGET_HOST}" "rm -v ${_ARCHIVE_FILE_NAME}"
