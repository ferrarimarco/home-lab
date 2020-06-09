#!/bin/sh

set -e

apt-get update
apt-get install \
    bison \
    ccache \
    cmake \
    coreutils \
    dfu-util \
    flex \
    git \
    gperf \
    libffi-dev \
    libssl-dev \
    ninja-build \
    python3 \
    python3-pip \
    python3-setuptools \
    wget

CURRENT_PWD="$(pwd)"

cd "$HOME" || exit 1

CMAKE_VERSION="$1"
echo "Installing CMake $CMAKE_VERSION..."

CMAKE_ARCHIVE_NAME=cmake-"$CMAKE_VERSION"-Linux-x86_64.tar.gz
echo "Downloading $CMAKE_ARCHIVE_NAME"

wget https://github.com/Kitware/CMake/releases/download/v"$CMAKE_VERSION"/"$CMAKE_ARCHIVE_NAME"-Linux-x86_64.tar.gz
tar xf "$CMAKE_ARCHIVE_NAME"

PATH="$(pwd)/cmake-$CMAKE_VERSION-Linux-x86_64/bin:$PATH"
export PATH

cmake --version

cd "$CURRENT_PWD" || exit 1
