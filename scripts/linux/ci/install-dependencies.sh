#!/bin/sh

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

echo "Installing CMake..."
CMAKE_ARCHIVE_NAME=cmake-"$CMAKE_VERSION".tar.gz
wget https://github.com/Kitware/CMake/releases/download/v"$CMAKE_VERSION"/"$CMAKE_ARCHIVE_NAME"
tar xf "$CMAKE_ARCHIVE_NAME"
cd cmake-"$CMAKE_VERSION" || exit 1
./bootstrap

cmake --version
