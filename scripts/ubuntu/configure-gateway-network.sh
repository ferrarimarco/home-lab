#!/bin/sh

set -e

vagrant_interface="$(find /sys/class/net \( -not -name lo -and -not -name 'docker*' -and -not -type d \) -printf "%f\\n" | sort | sed -n '1p')"
interface="$(find /sys/class/net \( -not -name lo -and -not -name 'docker*' -and -not -type d \) -printf "%f\\n" | sort | sed -n '2p')"

dns_nameserver=$2
domain=$4
gateway_ip_address=$1
subnet_mask=$3

echo "Configuring $interface interface with static IP address"

# We need to configure IP forwarding and iptables
echo "Enable IPv4 forwarding"
sed -i '/ipv4.ip_forward/s/^#//g' /etc/sysctl.conf
sysctl -p /etc/sysctl.conf

echo "Configuring iptables"
iptables --table nat --append POSTROUTING --out-interface "$vagrant_interface" -j MASQUERADE
# Add a line like this for each eth* LAN
iptables --append FORWARD --in-interface "$interface" -j ACCEPT

echo "Saving iptables rules"
mkdir -p /etc/iptables
iptables-save > /etc/iptables/rules.v4

# We are configuring the gateway network interface
# so don't add the default route via the gateway itself, otherwise we lose
# internet connettivity.
grep -q -F "auto $interface" /etc/network/interfaces \
|| printf "\\n\
auto %s\\n\
iface %s inet static\\n\
      address %s\\n\
      netmask %s\\n\
      dns-nameservers %s\\n\
      search %s\\n\
      pre-up sleep 5\\n\
      post-up iptables-restore < /etc/iptables/rules.v4\\n" \
      "$interface" \
      "$interface" \
      "$gateway_ip_address" \
      "$subnet_mask" \
      "$dns_nameserver" \
      "$domain" >> /etc/network/interfaces

printf "/etc/network/interfaces contents:\\n\
%s\\n\\n" "$(cat /etc/network/interfaces)"

echo "Restarting the networking service"
/etc/init.d/networking restart
