#!/bin/sh

set -e

CMAKE_VERSION="$1"

if [ -z "${CMAKE_VERSION}" ]; then
    echo 'The CMAKE_VERSION environment variable that specifies the CMake version to install is not defined. Terminating...'
    exit 1
fi

apt-get install -y \
    ca-certificates \
    wget

echo "Installing CMake $CMAKE_VERSION..."

CMAKE_ARCHIVE_NAME=cmake-"$CMAKE_VERSION"-Linux-x86_64.tar.gz
echo "Downloading $CMAKE_ARCHIVE_NAME"

wget https://github.com/Kitware/CMake/releases/download/v"$CMAKE_VERSION"/"$CMAKE_ARCHIVE_NAME"
tar xf "$CMAKE_ARCHIVE_NAME"
rm "$CMAKE_ARCHIVE_NAME"
