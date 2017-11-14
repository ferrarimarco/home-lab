#!/bin/sh

if which docker ; then
  echo "Docker is already installed"
else
  echo "Installing Docker..."
  apt-get update
  apt-get install --yes \
    apt-transport-https \
    ca-certificates \
    curl \
    linux-image-extra-"$(uname -r)" \
    linux-image-extra-virtual \
    software-properties-common
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
  add-apt-repository \
    "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
    $(lsb_release -cs) \
    stable"
  apt-get update
  apt-get install -y docker-ce=17.09.0~ce-0~ubuntu

  # add the vagrant user to the docker group if necessary
  VAGRANT_USERNAME="vagrant"
  if getent passwd $VAGRANT_USERNAME > /dev/null 2>&1; then
    echo "Adding vagrant user to the docker group"
    usermod -aG docker $VAGRANT_USERNAME
  fi
fi
