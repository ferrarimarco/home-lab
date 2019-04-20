#!/bin/sh

set -e

echo "Installing packages..."
apt-get update
apt-get install -y \
  curl \
  git \
  openssh-server
