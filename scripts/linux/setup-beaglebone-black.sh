#!/bin/sh

set -e

echo "Updating scripts and tools..."
cd /opt/scripts/
git pull

echo "Updating Kernel..."
/opt/scripts/tools/update_kernel.sh

echo "Updating bootloader..."
/opt/scripts/tools/developers/update_bootloader.sh

uENV_path="/boot/uEnv.txt"
if [ -e "$uENV_path" ]
then
  echo "Enabling eMMC flashing..."
  sed -i '/init-eMMC-flasher-v3.sh/s/^#*//g' "$uENV_path"
else
  echo "$uENV_path does not exist"
fi

echo "Configuring network interfaces"

printf "/etc/network/interfaces contents (before any edit):\\n\
%s\\n\\n" "$(cat /etc/network/interfaces)"

echo "Removing faulty network interfaces from /etc/network/interfaces. Let's start from a clean situation"
echo "
# This file describes the network interfaces available on your system
# and how to activate them. For more information, see interfaces(5).

source /etc/network/interfaces.d/*

# The loopback network interface
auto lo
iface lo inet loopback
" > /etc/network/interfaces

printf "/etc/network/interfaces contents (after cleaning up):\\n\
%s\\n\\n" "$(cat /etc/network/interfaces)"

reboot now
