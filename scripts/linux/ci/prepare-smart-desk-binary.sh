#!/bin/sh

set -e

BINARY_PATH="$1"
COMMIT_SHA="$2"
BRANCH_NAME="$3"
TAG_NAME="$4"

if [ -z "${BINARY_PATH}" ]; then
    echo 'The BINARY_PATH environment variable that points to the binary file is not defined. Terminating...'
    exit 1
fi

if [ -z "${COMMIT_SHA}" ]; then
    echo 'The COMMIT_SHA environment variable that holds the SHA of the commit is not defined. Terminating...'
    exit 1
fi

if [ -z "${BRANCH_NAME}" ]; then
    echo 'The BRANCH_NAME environment variable that holds the branch name is not defined. Terminating...'
    exit 1
fi

if [ -z "${TAG_NAME}" ]; then
    echo 'The TAG_NAME environment variable that holds the tag name is not defined. Terminating...'
    exit 1
fi

echo "Preparing $BINARY_PATH..."
