# Configuring the Asus RT-AX86U as a gateway for TIM

The Asus RT-AX86U replaces the TIM-supplied modem/router as the network gateway.
This document covers two scenarios:

- FTTH (current): the Asus connects to the [ZTE F6005 ONT](./zte-ont-access.md).
- FTTC (historical): the Asus connects to the
  [Technicolor DGA 4130 configured as a bridge](./technicolor-dga-4130-bridge.md).

## FTTH configuration

1. Connect the ONT to the WAN port of the Asus.
2. In the WAN connection configuration page, set the PPPoE username and password
   (see the TIM connection parameters below).
3. Set the VLAN ID (835) in the LAN, IPTV menu, in the internet (VID) field.

## FTTC configuration through the bridged DGA 4130

This procedure worked with the DGA 4130 configured as a bridge:

1. Enable bridge mode on the DGA 4130.
2. Enable VLAN tagging on the DGA 4130.
3. Set the DGA 4130 IP address to 192.168.0.1 and the subnet to /24. The subnet
   must be different from the subnet that the Asus router manages.
4. Enable DHCP on the DGA 4130.
5. Configure the PPPoE connection on the Asus.
6. Configure the WAN interface IP address. Example:
    - Asus router WAN interface IP address: 192.168.0.2
    - Subnet mask: 255.255.255.0
    - Gateway (must be the IP address of the bridge on the DGA 4130):
      192.168.0.1
7. Ensure that you can access the DGA 4130 management interface from the Asus
   router subnet.
8. Backup the DGA 4130 configuration.
9. Backup the Asus router configuration.

### Findings from the experiments

- The Asus WAN interface doesn't get a DHCP lease from the bridged DGA 4130, so
  reaching the hub's management interface requires manually configuring the
  local IP address of the Asus WAN interface on the DGA 4130 subnet, as in the
  procedure above.
- Configuring the VLAN tagging on the Asus (LAN, IPTV menu, Manual) instead of
  on the DGA 4130 failed: the tagging had to stay on the DGA 4130.
- The "WAN IP Setting" section of the Asus configuration contains the IP
  settings of the subnet composed of the modem connected to the WAN port of the
  Asus and the Asus itself.
- The WAN interface is `eth0` because it's the only one that's not in the `br0`
  bridge (run `brctl show`). See
  [Getting access to the ZTE ONT](./zte-ont-access.md).

## TIM connection parameters

Source:
[TIM: modem generico](https://www.tim.it/assistenza/assistenza-tecnica/guide-manuali/modem-generico)
(in Italian).

### FTTC

The router must support the VDSL2 standard with 8b and 17a spectrum profiles
(35b recommended), and the following features:

- Retransmission (ITU-T G.998.4)
- Vectoring (ITU-T G.993.5)
- SRA (ITU-T G.993.2)

Always-on connection parameters:

- Username: the line's phone number
- Password: timadsl
- Protocol: PPPoE Routed (RFC 2516)
- Encapsulation: PTM
- NAT: enabled
- VLAN: 835
- IGMP proxy: disabled
- Routing: unicast traffic

### FTTH

The fiber terminates in a TIM-supplied ONT (Optical Network Termination).
Connect the router to the ONT with a category 5e or better ethernet cable, on
the WAN port. The WAN interface must be gigabit ethernet full-duplex
auto-sensing, with 802.1q support.

Always-on connection parameters:

- Username: the line's phone number
- Password: timadsl
- Protocol: PPPoE Routed (RFC 2516)
- Encapsulation: VLAN Ethernet 802.1q
- NAT: enabled
- VLAN: 835
- IGMP proxy: disabled
- Routing: unicast traffic

### Video Live multicast (optional)

For optimized (multicast) TIM Video Live services, configure a second
connection:

- Protocol: IPoE (Static IP)
- IP address: 10.10.10.2
- IP subnet: 255.255.255.252
- VLAN: 836
- IGMP Proxy v2: enabled, forcing IGMPv2
- Routing: multicast traffic
- Enable IGMP snooping on the LAN interface

This second connection is not required for Video Live services to work.

### VoIP

To use TIM voice services in VoIP mode on FTTC and FTTH lines, configure the
VoIP service on the modem. Get the configuration data via SMS by opening a
support request in the MyTIM private area (Internet section, "Parametri TIM per
modem generico" request). The data can only be obtained for the TIM line you're
browsing from.

The router must use the DNS servers obtained automatically during the
connection, and must be able to issue SRV queries to them. Some devices might
require additional parameters:

- SIP domain: telecomitalia.it
- SIP protocol: UDP port 5060
- Expire time: 86400 seconds minimum
- Mandatory codecs: G.729, G.711 A-law
- Optional codec: G.722
- Fax and POS handled with G.711 A-law and T.38
- Packetization time: 20 ms
- DTMF tones: RFC 2833 / RFC 4733
- DSCP marking: 40 (decimal)
- VAD (Voice Activity Detection): disabled
- 100rel support (PRACK message, RFC 3262): enabled
- UPDATE support (RFC 3311): enabled

## References

- [Router generico (Asus RT-AX86U) e FTTH](https://forum.fibra.click/d/23793-router-generico-asus-rt-ax86u-e-ftth)
- [TIM: modem generico](https://www.tim.it/assistenza/assistenza-tecnica/guide-manuali/modem-generico)
- [TIM: connessione FTTH](https://assistenzatecnica.tim.it/at/portals/assistenzatecnica.portal?_nfpb=true&_pageLabel=InternetBook&radice=consumer_root&nodeId=/AT_REPOSITORY/880003)
