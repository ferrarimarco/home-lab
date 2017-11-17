#!/bin/sh

if which docker >/dev/null 2>&1 ; then
  echo "Docker is already installed"
else
  curl -sSL https://get.docker.com | sh
  usermod -aG docker vagrant
fi
