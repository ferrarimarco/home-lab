#!/bin/sh

set -e

BINARY_FILE_PATH="$1"
COMMIT_SHA="$2"
BRANCH_NAME="$3"
TAG_NAME="$4"

if [ -z "${BINARY_FILE_PATH}" ]; then
    echo 'The BINARY_FILE_PATH environment variable that points to the binary file is not defined. Terminating...'
    exit 1
fi

echo "Binary file path: ${BINARY_FILE_PATH}"

BINARY_FILE_NAME="$(basename "${BINARY_FILE_PATH}")"
echo "Binary file name: ${BINARY_FILE_NAME}"

BINARY_FILE_NAME_NO_EXT="$(basename "${BINARY_FILE_PATH}" | cut -d. -f1)"
echo "Binary file name without extension: ${BINARY_FILE_NAME_NO_EXT}"

if [ -z "${COMMIT_SHA}" ]; then
    echo 'The COMMIT_SHA environment variable that holds the SHA of the commit is not defined. Terminating...'
    exit 1
fi

if [ -z "${BRANCH_NAME}" ]; then
    echo 'The BRANCH_NAME environment variable that holds the branch name is not defined. Terminating...'
    exit 1
fi

if [ -z "${TAG_NAME}" ]; then
    echo 'The TAG_NAME environment variable that holds the tag name is not defined.'
fi

NEW_BINARY_FILE_NAME="${BINARY_FILE_NAME_NO_EXT}-${BRANCH_NAME}-${COMMIT_SHA}.bin"
NEW_BINARY_FILE_PATH="$(dirname "${BINARY_FILE_PATH}")/${NEW_BINARY_FILE_NAME}"

echo "Preparing $BINARY_PATH..."

echo "Moving $BINARY_PATH to $NEW_BINARY_FILE_PATH..."
mv "$BINARY_PATH" "$NEW_BINARY_FILE_PATH"
