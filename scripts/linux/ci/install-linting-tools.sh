#!/bin/bash

set -e
set -o pipefail

pip3 install \
    setuptools \
    wheel

pip3 install -r requirements.txt

GIMME_GO_VERSION="1.14.3"
GIMME_ARCH=amd64
GIMME_OS=linux
echo "Installing Go $GIMME_GO_VERSION ($GIMME_ARCH $GIMME_OS)"
eval "$(GIMME_GO_VERSION=$GIMME_GO_VERSION GIMME_ARCH=$GIMME_ARCH GIMME_OS=$GIMME_OS gimme)"

GO111MODULE=on go get mvdan.cc/sh/v3/cmd/shfmt

echo "Installing npm packages..."
npm install -g markdownlint-cli
