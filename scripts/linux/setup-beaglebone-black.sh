#!/bin/sh

set -e

echo "Updating scripts and tools..."
cd /opt/scripts/
git pull

echo "Updating Kernel..."
/opt/scripts/tools/update_kernel.sh --lts-4_19

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

# The primary network interface
#auto eth0
#iface eth0 inet dhcp
# Example to keep MAC address between reboots
#hwaddress ether DE:AD:BE:EF:CA:FE

##connman: ethX static config
#connmanctl services
#Using the appropriate ethernet service, tell connman to setup a static IP address for that service:
#sudo connmanctl config <service> --ipv4 manual <ip_addr> <netmask> <gateway> --nameservers <dns_server>

# Ethernet/RNDIS gadget (g_ether)
# Used by: /opt/scripts/boot/autoconfigure_usb0.sh
#iface usb0 inet static
#    address 192.168.7.2
#    netmask 255.255.255.252
#    network 192.168.7.0
#    gateway 192.168.7.1

" > /etc/network/interfaces

printf "/etc/network/interfaces contents (after cleaning up):\\n\
%s\\n\\n" "$(cat /etc/network/interfaces)"

reboot now
