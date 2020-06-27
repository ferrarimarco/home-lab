#!/bin/bash

set -e
set -o pipefail

sudo apt-get update

sudo apt-get install \
    python3 \
    python3-pip \
    python3-setuptools

pip3 install \
    setuptools \
    wheel

pip3 install -r requirements.txt

echo "Installing npm packages..."
npm install -g markdownlint-cli
