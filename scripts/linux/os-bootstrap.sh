#!/bin/sh

set -e

# This is currently Debian-specific
echo "Installing packages"
apt-get update
apt-get install -y \
  curl \
  git \
  openssh-server

echo "Configuring SSH directory"
mkdir -p "$HOME"/.ssh
chmod 700 "$HOME"/.ssh

echo "Configuring authorized keys"
curl -l http://github.com/ferrarimarco.keys > "$HOME"/.ssh/authorized_keys
chmod 600 "$HOME"/.ssh/authorized_keys

echo "Starting SSH server"
systemctl enable ssh
systemctl restart ssh

echo "Cloning repository"
cd /opt
git clone https://github.com/ferrarimarco/home-lab.git
