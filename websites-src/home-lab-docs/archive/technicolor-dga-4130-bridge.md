# Configuring the Technicolor DGA 4130 (AGTEF) as a bridge

The Technicolor DGA 4130 (TIM Hub, AGTEF board) was the TIM-supplied
modem/router. Configuring it as a bridge lets a downstream router (the Asus
RT-AX86U) establish the PPPoE session and act as the network gateway.

This procedure requires a rooted device running
[Ansuel's modified GUI (tch-nginx-gui)](https://github.com/Ansuel/tch-nginx-gui).

## Configure bridge mode

1. In the Broadband menu, select the interface to put in the bridge. If you
   configure a VLAN here, the bridged interface comes out already tagged.
2. In the internet menu, select bridge mode.

Don't use the bridge mode toggle on the Broadband page itself: it is broken (it
also disables Wi-Fi and other services), and if you used it, do a factory reset
to be safe.

## Management access after bridging

After setting bridge mode, the DGA 4130 keeps its LAN IP address and routing, so
its management GUI stays reachable: connect a PC with an address on the same
subnet (for example 192.168.1.2 when the hub is 192.168.1.1), or reach it from
the downstream router with matching addressing.

## Keep the DGA 4130 online (optional, needed for VoIP)

The bridge configuration is designed to take the hub itself offline. To keep it
connected to the internet through the downstream router (for example to keep
VoIP working):

- Put the hub's LAN IP address on the downstream subnet.
- Disable the hub's DHCP server when the downstream device manages DHCP.
- Set a static route to the real gateway (the downstream router), or set the
  `br-lan` interface to DHCP so the hub learns its IP address and default route
  from the downstream DHCP server.

## Configure the bridge without the GUI

Add the broadband interface to the LAN bridge in `/etc/config/network`: in the
`config interface 'lan'` block, add `list ifname 'ptm0'`.

## References

- [Disattivare parte routing TIM HUB con GUI Ansuel](https://www.ilpuntotecnico.com/forum/index.php?topic=82683.0)
- [TIM HUB in bridge](https://www.ilpuntotecnico.com/forum/index.php/topic,80632.0.html)
- [TIM HUB bridge mode configuration](https://www.ilpuntotecnico.com/forum/index.php/topic,82068.0.html)
- [TIM HUB DGA4132 in BRIDGE su FTTC VULA Fastweb, senza GUI Ansuel](https://www.ilpuntotecnico.com/forum/index.php/topic,83017.0.html)
- [TIM HUB DGA4132 Ansuel come AP e VoIP](https://www.ilpuntotecnico.com/forum/index.php?topic=81419.0)
- Sources of the Ansuel GUI helpers, to understand what the settings above do:
    - [internetmode_helper.lua](https://github.com/Ansuel/tch-nginx-gui/blob/master/decompressed/gui_file/www/lua/internetmode_helper.lua)
    - [broadbandmode_helper.lua](https://github.com/Ansuel/tch-nginx-gui/blob/master/decompressed/gui_file/www/lua/broadbandmode_helper.lua)
    - [sys.eth.map](https://github.com/Ansuel/tch-nginx-gui/blob/master/decompressed/gui_file/usr/share/transformer/mappings/rpc/sys.eth.map)
