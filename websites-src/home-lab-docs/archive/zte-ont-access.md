# Getting access to the ZTE ONT

The ZTE F6005 ONT terminates the TIM FTTH line and sits upstream of the Asus
RT-AX86U gateway. This document describes how to reach its management interface,
for example to check the optical link status.

## Identify the WAN interface on the gateway

The 2.5 Gbps port is `eth0` on the Asus RT-AX86U. `eth0` is not in the `br0`
bridge, so it is the WAN interface:

```text
marco@gateway:/tmp/home/root# brctl show
bridge name  bridge id          STP enabled  interfaces
br0          8000.f02f74924f38  yes          eth1
                                             eth2
                                             eth3
                                             eth4
                                             eth5
                                             eth6
                                             eth7
```

`eth0` is the 2.5 Gbps interface:

```text
marco@gateway:/tmp/home/root# ethctl eth0 media-type
Auto Detection of Serdes: Enabled
PHY Capabilities: 2.5GFD|1GFD|100MFD
Link is Up at Speed: 2.5G, Duplex: FD
```

In previous firmware versions, the 2.5 Gbps interface was `eth5`.

## Reach the ONT

The ZTE ONT has a static IPv4 address: `192.168.1.1`. Verify that it is
reachable at the data link layer:

```text
marco@gateway:/tmp/home/root# arping -I eth0 192.168.1.1
ARPING to 192.168.1.1 from 192.168.0.2 via eth0
Unicast reply from 192.168.1.1 [28:77:77:24:22:7c] 1.265ms
```

To reach the ONT from the gateway, add a route to it:

```shell
ip route add 192.168.1.1/32 dev eth0
```

Configure NAT because the ONT doesn't have a route back to the gateway, and
sends all traffic to the optical interface:

```shell
iptables -t nat -I POSTROUTING -o eth0 -j MASQUERADE
```

When VLAN tagging is enabled on the WAN connection, connecting through the
router doesn't work because the router tags the frames and the ONT doesn't strip
the tag: connect an ethernet cable directly to the ONT instead.

## Log in

The management interface is at `https://192.168.1.1` (self-signed certificate).
The credentials are the vendor defaults, which are easy to guess and publicly
documented:

- User: admin
- Password: admin

The interface behaves as follows (firmware V6.0.10N20, probed from raspberrypi2
on 2026-11-16, 12 days after a power cycle):

- Port 80 only redirects: the root to the login page, and the login page, the
  data pages, and the login form to their HTTPS addresses.
- The web server is GoAhead, going by the name of its session cookie
  (`-goahead-session-`). The login is a POST to `/goform/LoginForm` that sets
  the cookie, and the cookie alone identifies the session, on any connection. An
  idle session was still valid after 20 minutes and gone after 35, and other
  logins from the same address do not end it.
- A request without a valid session gets a 401, and a request with the cookie of
  a logged-out session a 302 to the login page.
- An empty POST to `/goform/LogoutForm` ends the session.
- A new connection is expensive: the TLS handshake took about 7 seconds and the
  first request on the connection 4 to 6 more, while a request on an open
  connection took under a second, or up to 4 while a second client was logging
  in.
- The ONT closes a connection that stays idle for about a minute: reads 30 to 50
  seconds apart reused the connection, a read after 55 seconds got a 408
  "Request Timeout" although its session was still valid, and the one after that
  took as long as a new connection does.
- The server appears to handle one request at a time: while one client was
  logging in, the requests of a second one took 10 to 20 seconds longer.
- The `Date` header of every response counts from 1970-01-01 at boot, so it
  gives the ONT's uptime, which no page reports.

## Automation

The manual procedure above has been automated as part of the ONT monitoring
stack that the `ferrarimarco_home_lab_node` Ansible role deploys:

- `config/ansible/roles/ferrarimarco_home_lab_node/files/config/monitoring-ont/configure-route-to-ont.sh`
  configures access to the ONT idempotently: it discovers the WAN interface from
  `nvram get wan_ifname`, adds the route and the MASQUERADE rule if missing, and
  assigns a local address on the ONT subnet to the WAN interface.
- `config/ansible/roles/ferrarimarco_home_lab_node/files/config/monitoring-ont/zte-f6005-ont-exporter.py`
  is a custom Prometheus exporter that logs in to the ZTE F6005 management
  interface and exports its metrics.
- The systemd services and timer in
  `config/ansible/roles/ferrarimarco_home_lab_node/templates/monitoring-ont`
  orchestrate the two: `monitoring-ont-network-config.service` (triggered by its
  timer) runs the network configuration script, and
  `zte-f6005-ont-exporter.service` runs the exporter.

## References

- [Hack-GPON: ZTE F6005](https://hack-gpon.org/ont-zte-f6005/)
