#!/bin/sh

set -e

CMAKE_VERSION="$1"

if [ -z "${CMAKE_VERSION}" ]; then
    echo 'The CMAKE_VERSION environment variable that specifies the CMake version to install is not defined. Terminating...'
    exit 1
fi

CMAKE_BIN_DIR_PATH="$(pwd)/cmake-$CMAKE_VERSION-Linux-x86_64/bin"
echo "Adding $CMAKE_BIN_DIR_PATH to PATH..."
PATH="$CMAKE_BIN_DIR_PATH:$PATH"
export PATH

cmake --version

idf.py build
