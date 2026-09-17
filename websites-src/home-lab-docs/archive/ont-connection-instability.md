# ONT connection instability

Starting on 2022-05-16, the WAN connection dropped intermittently: the PON LED
on the [ZTE ONT](./zte-ont-access.md) flashed, and the connection came back
after 5-10 seconds. While the PON connection was down, the internet connection
was down too.

Root cause: a faulty ONT. TIM replaced it, solving the issue.

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
