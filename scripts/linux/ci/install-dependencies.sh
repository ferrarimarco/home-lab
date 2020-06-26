#!/bin/sh

set -e

if [ -z "${CMAKE_VERSION}" ]; then
    echo 'The CMAKE_VERSION environment variable that specifies the CMake version to install is not defined. Terminating...'
    exit 1
fi

CURRENT_PWD="$(pwd)"

echo "PWD: $CURRENT_PWD"

cd "$HOME" || exit 1

CMAKE_VERSION="$1"
echo "Installing CMake $CMAKE_VERSION..."

CMAKE_ARCHIVE_NAME=cmake-"$CMAKE_VERSION"-Linux-x86_64.tar.gz
echo "Downloading $CMAKE_ARCHIVE_NAME"

wget https://github.com/Kitware/CMake/releases/download/v"$CMAKE_VERSION"/"$CMAKE_ARCHIVE_NAME"
tar xf "$CMAKE_ARCHIVE_NAME"

PATH="$(pwd)/cmake-$CMAKE_VERSION-Linux-x86_64/bin:$PATH"
export PATH

cmake --version

cd "$CURRENT_PWD" || exit 1
