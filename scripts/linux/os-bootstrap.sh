#!/bin/sh

set -e

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
