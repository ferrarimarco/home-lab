#!/usr/bin/env bash

# Write the manifest of a directory tree: one line per file with its path
# relative to the directory, its size in bytes, and its modification time in
# UTC, tab-separated and sorted by path, so that what a media disk held is
# known after the disk is lost. A file name that holds a tab or a newline
# breaks its line.
#
# An empty tree is a valid listing. When it replaces a manifest that lists
# files, that manifest is kept beside it under the .last-non-empty.tsv suffix:
# a share served empty, with the directory present, reads the same as a
# library emptied on purpose. A listing that fails, a missing directory
# included, leaves the manifest as it was.

set -o errexit
set -o nounset
set -o pipefail

SOURCE_DIRECTORY_PATH="${1}"
MANIFEST_FILE_PATH="${2}"
METRICS_FILE_PATH="${3}"

LAST_NON_EMPTY_MANIFEST_FILE_PATH="${MANIFEST_FILE_PATH%.tsv}.last-non-empty.tsv"

# Both files are written beside their destination and renamed, so that a
# reader (the backup, the node exporter) never sees a partial one
TEMPORARY_MANIFEST_FILE_PATH=""
TEMPORARY_METRICS_FILE_PATH=""
trap 'rm -f "${TEMPORARY_MANIFEST_FILE_PATH}" "${TEMPORARY_METRICS_FILE_PATH}"' EXIT
TEMPORARY_MANIFEST_FILE_PATH="$(mktemp "${MANIFEST_FILE_PATH}.XXXXXX")"
TEMPORARY_METRICS_FILE_PATH="$(mktemp "${METRICS_FILE_PATH}.XXXXXX")"

# find prints the seconds with a fraction, which the manifest drops
TZ=UTC find "${SOURCE_DIRECTORY_PATH}" -type f -printf '%P\t%s\t%TY-%Tm-%TdT%TH:%TM:%TSZ\n' |
  sed -E 's/\.[0-9]+Z$/Z/' |
  LC_ALL=C sort >"${TEMPORARY_MANIFEST_FILE_PATH}"

MANIFEST_FILES_COUNT="$(wc -l <"${TEMPORARY_MANIFEST_FILE_PATH}")"
echo "Listed ${MANIFEST_FILES_COUNT} files under ${SOURCE_DIRECTORY_PATH}"

if [ "${MANIFEST_FILES_COUNT}" -eq 0 ] && [ -s "${MANIFEST_FILE_PATH}" ]; then
  echo "The listing is empty: keeping the previous manifest as ${LAST_NON_EMPTY_MANIFEST_FILE_PATH}"
  mv "${MANIFEST_FILE_PATH}" "${LAST_NON_EMPTY_MANIFEST_FILE_PATH}"
fi

chmod 0644 "${TEMPORARY_MANIFEST_FILE_PATH}"
mv "${TEMPORARY_MANIFEST_FILE_PATH}" "${MANIFEST_FILE_PATH}"

cat >"${TEMPORARY_METRICS_FILE_PATH}" <<EOF
# HELP media_manifest_files Files listed in the media manifest.
# TYPE media_manifest_files gauge
media_manifest_files ${MANIFEST_FILES_COUNT}
EOF
chmod 0644 "${TEMPORARY_METRICS_FILE_PATH}"
mv "${TEMPORARY_METRICS_FILE_PATH}" "${METRICS_FILE_PATH}"
