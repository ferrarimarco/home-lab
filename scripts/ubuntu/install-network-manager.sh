#!/bin/sh

set -e

if [ "$(dpkg-query -W -f='${Status}' network-manager 2>/dev/null | grep -c 'ok installed' || true)" -eq 0 ];
then
  echo "Installing NetworkManager"
  apt-get update
  apt-get install -y network-manager

  echo "Disabling dnsmasq used by NetworkManager"
  sed -i '/dnsmasq/d' /etc/NetworkManager/NetworkManager.conf


  echo "Reconfigure resolvconf to fix missing symbolic links"
  dpkg-reconfigure -f noninteractive resolvconf
fi

ENABLED=$(systemctl status NetworkManager.service | grep -c 'enabled;' || true)
if [ "$ENABLED" -ne 1 ];
then
  echo "Enabling NetworkManager service"
  systemctl enable NetworkManager.service
else
  echo "NetworkManager service already enabled"
fi

UP=$(systemctl status NetworkManager.service|grep -c 'Active: active' || true)
if [ "$UP" -ne 1 ];
then
  echo "Starting NetworkManager service"
  systemctl start NetworkManager.service
else
  echo "NetworkManager service already running"
fi
