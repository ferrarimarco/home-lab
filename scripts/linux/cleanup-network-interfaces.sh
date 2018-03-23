#!/bin/sh

set -e

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
