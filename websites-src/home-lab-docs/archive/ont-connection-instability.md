# ONT connection instability

Starting on 2022-05-16, the WAN connection dropped intermittently: the PON LED
on the [ZTE ONT](./zte-ont-access.md) flashed, and the connection came back
after 5-10 seconds. While the PON connection was down, the internet connection
was down too.

Root cause: a faulty ONT. TIM replaced it, solving the issue.

The replacement (model F6005V6.0, software V6.0.10N20) has a different failure
mode, recorded in [The 2026-11-04 hang](#the-2026-11-04-hang) below.

## Investigation

- Checked the ONT admin interface while the issue was happening:
    - The temperature stayed within 50-53 degrees Celsius.
    - The status transitioned to "Standby state(O2)" and then back to "Operation
      state(O5)". This doesn't mean too much by itself, because it might be a
      regular state transition.
    - The attenuation was around -18 dBm when the ONT was in standby state.
- Disconnected the router from the ONT: the ONT drops the connection even if no
  router is connected, so the issue is not caused by the router.
- Planned to connect the TIM Smart modem overnight (connected 2022-05-21 17:20,
  disconnected 2022-05-21 20:00), but there was no need to complete the test
  because the ONT loses the connection even without any router connected.
- Reverted the gateway to the 3.0.0.4.386_45934 firmware on 2022-05-20 9:14 to
  investigate: it didn't change anything in regards to the disconnection issue,
  so we reinstalled 3.0.0.4.386_46061 on 2022-05-20 18:38.

## ONT notes gathered during the investigation

To check the ONT admin interface, connect an ethernet cable directly to the ONT:
the router routes packets correctly to 192.168.1.1, but adds a VLAN tag, and the
ONT doesn't reverse the operation. See
[Getting access to the ZTE ONT](./zte-ont-access.md).

GPON ONT states:

1. Initial-state(O1): when the ONU is powered on, it is in this state, namely
   LOS/LOF state.
2. Standby-state(O2): when the ONU receives downstream traffic, it enters the O2
   state. When the ONU receives a packet of type Upstream_Overhead message, it
   configures some corresponding options, including delimiter value, power level
   mode, and pre-assigned equalization delay.
3. Serial-Number-state(O3): when entering O3, the OLT sends a Serial_Number
   request to the ONU, and the ONU replies with its own serial number and
   password. After the OLT authenticates it, it sends an ONU ID to the ONU
   through the Assign_ONU-ID message. When the ONU receives the ONU ID, it
   enters the O4 state.
4. Ranging-state(O4): logical ranging stage. When the ONU receives the reply
   sent by the OLT, it enters O5.
5. Operation-state(O5): after entering this state, the ONU can directly send
   uplink data and PLOAM messages.
6. POPUP-state(O6): when the ONU detects the loss of the optical signal, it
   enters this state, and then turns to the O1 state.
7. Emergency-Stop-state(O7): when the ONU receives the Disable_Serial_Number
   message, it enters this state and then turns to the O2 state.

## The 2026-11-04 hang

The ONT hangs in a state that only a power cycle clears. Its admin interface
hung from 2026-03-28 to 2026-11-04, starving the ONT exporter, and on 2026-11-04
its forwarding plane hung too: the WAN was down from 01:20 to 06:12 UTC while
the PON LED stayed on, the gateway's Ethernet link to the ONT stayed up at 2.5
Gbps, PPPoE discovery got no reply, and the ONT answered no ARP. The router WAN
check restarted the WAN 98 times without effect (its only action is a PPPoE
restart on the router), a manual power cycle restored the PPPoE session within
seconds, and the admin interface came back with it (the exporter runs again
since 06:30 UTC, its first data since March).

Verified the same day: the admin interface serves three read-only pages (device,
GPON, and LAN port info) with no log, no uptime (it is only in the `Date` header
of the responses, as the [access notes](./zte-ont-access.md#log-in) describe),
and no reboot control, so a smart plug is the only remote recovery lever; the
ONT keeps no log and its counters restart with power, so the router log is the
only record of an outage start. The ONT is a closed, ISP-managed device, so
root-causing is likely not possible. The remote power cycle design is an item in
the [specs todo list](../architecture/README.md#issues-to-solve), and the WAN
check changes it needs are under
[Networking](../architecture/README.md#networking) there.

## The slow admin interface of 2026-11-13

From 2026-11-12 23:42 UTC, 8.7 days after the power cycle, the exporter's logins
started to fail, more of them by the hour (none of about 100 an hour before, 40
of 63 by 13:00 UTC on 2026-11-13), while the WAN stayed up and the ONT reported
the operation state at every successful login. The admin interface was not hung,
only slower than the exporter's timeout:

- On 2026-11-14 the ONT answered six unauthenticated HTTPS requests out of six,
  in 7 to 11 seconds, of which the TLS handshake took 6 to 7.7 seconds. The
  exporter gave up at 5 seconds: its connect timeout, which also bounds the
  handshake.
- The handshakes of the logins that succeeded took 3.6 to 5 seconds (median 4.4
  to 4.7), so that timeout had little margin before the slowdown either.
- The same request over plain HTTP was answered in 1.4 seconds, with a redirect
  to a login page over HTTP.

What slowed the handshake is not known, and neither is whether the interface was
hung or only this slow before 2026-11-04. The exporter itself is a candidate
cause: it opens a new session, with a handshake and a login, 30 seconds after
each read (about 2,500 a day) and never logs out.

Since 2026-11-16 the exporter has a connect timeout of 30 seconds, and the
`OntMetricsMissing` rule reads the share of samples that carry the GPON state
([Monitoring Alerting](../architecture/monitoring-alerting.md#613-ont)). In the
half hour after that change all 44 logins succeeded, in 8 to 15 seconds each
(median 12), the unit did not restart, and the two alerts it had raised
resolved.

## The lighter exporter of 2026-11-16

The exporter's journal and probes of the admin interface on 2026-11-16 showed
where the exporter's cost was; the [access notes](./zte-ont-access.md#log-in)
record how the interface behaves. By the journal, each login took 8 to 15
seconds, a TLS handshake of about 7 and a login request of about 5, against one
to two seconds for the three page reads that followed. The ONT also appears to
answer one request at a time: while a probe was logging in, the exporter's login
and reads took 10 to 20 seconds longer than otherwise, and the probes were
delayed the same way. With a login 30 seconds after each read, the exporter
would then keep the interface busy for about 30 percent of the time. Plain HTTP
is no alternative, since port 80 only redirects to HTTPS.

The exporter now logs in once and keeps the session and its connection. It reads
the GPON and LAN port pages every 30 seconds, an interval that keeps the
connection open, and the device page once; it logs in again when the ONT no
longer accepts the session, and logs out when it stops. It also exports the
ONT's uptime (`ztef6005ont_uptime_seconds`), the time each read takes
(`ztef6005ont_read_duration_seconds`), and the time the last login took
(`ztef6005ont_login_duration_seconds`), so that the next slowdown, or its
absence, can be read against the time since the last boot. The login is the
measure of what degraded on 2026-11-13, since it includes the handshake of a new
connection, and the exporter logs in only when it starts or loses its session: a
restart of its unit takes a sample.

The exporter runs on raspberrypi2 since 2026-11-16 14:25 UTC, with the ONT up
for 12.3 days. In its first 42 minutes it logged in once and read 83 times, each
read taking at most 0.64 seconds (median 0.42), and no alert fired. That first
login took 18.6 seconds, but the exporter it replaced was stopped in the middle
of a login of its own, so the sample is not a clean one. Whether the interface
now stays fast is what the item in the
[specs todo list](../architecture/README.md#monitoring-and-alerting) waits to
learn.
