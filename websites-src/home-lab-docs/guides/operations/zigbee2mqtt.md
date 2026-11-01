# Zigbee2MQTT operations

Zigbee2MQTT runs on raspberrypi2 as the `zigbee2mqtt` service of the
`zigbee2mqtt` Compose stack, with its data under
`/etc/ferrarimarco-home-lab/zigbee2mqtt/data`. The node role renders only the
configuration file there; the device list, the network state, and every device
setting live on the devices and in that data directory, so the operations below
change nothing in the repository.

## Read a device's state and history

- `devices.yaml` maps IEEE addresses to friendly names.
- `database.db` holds one JSON line per device: model, firmware (`swBuildId` and
  `dateCode`), and the last known cluster attributes.
- The container log carries every state publish, so it is the device's history
  without a database. The log line of a publish names the device by friendly
  name; this prints the transitions of one boolean property as a timeline:

    ```shell
    docker logs zigbee2mqtt --since 12h 2>&1 \
      | grep "topic 'zigbee2mqtt/<friendly name>'" \
      | grep -o "^\[[^]]*\].*\"occupancy\":[a-z]*" \
      | sed -E "s/\] .*\"occupancy\":/] occupancy=/" \
      | uniq -f2
    ```

- Home Assistant keeps the same history with the rest of the house's entities,
  which is what a correlation needs: the
  [Home Assistant operations guide](./home-assistant.md) describes how to query
  its recorder database.

## Write a device setting through the MQTT API

Zigbee2MQTT's API is its MQTT topic contract: a device's settings and commands
go to `zigbee2mqtt/<friendly name>/set`, and the bridge's own operations to
`zigbee2mqtt/bridge/request/...` (the
[MQTT topics and messages](https://www.zigbee2mqtt.io/guide/usage/mqtt_topics_and_messages.html)
page of its documentation; the frontend's WebSocket is internal). The broker
accepts open connections and its host carries the client tools (the
[MQTT Broker specification](../../architecture/mqtt-broker.md) names the host
and the role that installs them), so a setting is one publish from the broker
host against localhost:

```shell
mosquitto_pub -h localhost \
  -t 'zigbee2mqtt/<friendly name>/set' -m '{"<property>": <value>}'
```

Zigbee2MQTT writes the attribute and the device answers with a state publish
that carries the new value: read it back from the log before trusting the write.
Send one property per publish: a message carrying several properties (three zone
flags, on the kitchen sensor) applied only the first one and dropped the rest
without an error in the log. The device page on the Zigbee2MQTT site
(`https://www.zigbee2mqtt.io/devices/<model>.html`) lists every property with
its range, and commands (a calibration start, for example) go through the same
topic. For a setting that Home Assistant exposes as an entity, the interface is
the higher-level route to the same call.

## Tune a mmWave presence sensor

The procedure below was worked out on the kitchen sensor in October 2026 and
applies to any radar presence sensor that exposes a timeout, zones, a
sensitivity, and a learning command.

1. Place the sensor as the vendor describes (for the Sonoff SNZB-06P24: 1 to 2 m
   high, aimed at chest height, a 120 degree cone, about 4 m of range) so that
   the cone ends at a wall rather than a doorway, and keep fans, appliances, and
   large metal surfaces out of it where possible. Everything below compensates
   for what placement cannot avoid.
2. Update the firmware first, through the OTA entity. A release can rework the
   sensitivity mapping and reset settings: 1.0.4 of the SNZB-06P24 set the
   timeout back to its new default of 120 s.
3. Set the occupancy timeout. The sensor re-triggers within a second while
   someone is there, so 45 s is enough for lighting and keeps false detections
   short.
4. Run the spatial learning (the vendor's "Detection Calibration") with the room
   empty and the fixed interference sources running, the oven's convection fan
   for example. It takes about 30 s and ends with the state `Clear`, or
   `Failed`. Each run replaces the learned profile: run it again after moving
   the sensor or a source. The device reports raw detections while it learns, so
   ignore those. On firmware 1.0.4 of the SNZB-06P24 the run also resets the
   sensitivity to 0 without a message in the log: read the state back after
   every run.
5. Measure before tuning anything else. A false detection reads as one trigger
   followed by the timeout, never re-triggered, while a real visit re-triggers
   and lasts longer. Count the brief ones over a window the room is known to be
   empty, the night, and compare the rate with the candidates: a plug's power
   readings for an appliance, and the house's entity history for everything
   else, ranked against what chance gives (a reading that changes every minute
   lands within a minute of any event). A window of T hours is clean by luck
   with probability e^(-rT) at a background rate of r per hour: 40 minutes at
   5.5 per hour leaves 2.5 percent, enough to decide.
6. Measure the walk-bys. A person crossing the cone reads as a few seconds of
   detection plus the timeout, while someone using the covered area re-triggers
   for minutes, so the recorder history of the occupancy entity (the
   [Home Assistant operations guide](./home-assistant.md) has the query) sorts
   the episodes by length: subtract the timeout from each and count the ones
   under about 15 s over a morning or an evening of normal use. A high share
   means the cone takes in a walkway, and only the sensor can fix it: a consumer
   sees the same signal for a crossing and a visit until the timeout expires, so
   any filter on its side costs at least the timeout in latency. Re-aim or move
   the head so that the cone ends at the covered area, run the learning again,
   and repeat the count over a comparable window.
7. Locate the source with the zones. The zones are radial distance bands, so
   disabling one blinds it across the whole cone. Disable the far bands, test an
   empty window, then re-enable them one at a time with a window each; the band
   that brings the detections back holds the source.
8. Change the sensitivity last, when the zones have shown that the detections
   come from every band rather than from one source. Run the learning first and
   write the sensitivity after it, since the run resets it, then test each value
   over an empty window of two hours or more, starting from the lowest value
   that still detects a person at the worktop and stepping up: the measurements
   above are what each step is compared against.

The sensor ships without a power supply, and a faulty USB charger is a confirmed
failure cause rather than a source of brief triggers: on 2026-10-30 the kitchen
sensor dropped off the network with occupancy held true, so the light it had
switched on stayed on, because the off automation triggers on the change to
clear and the entity went unavailable instead. Another candidate for random
brief triggers, not confirmed: the cooling fan an oven runs after switch-off,
which the learning run does not cover when it ran with the oven on.

## Kitchen presence sensor

The sensor named "Presenza cucina" is a Sonoff SNZB-06P24 on firmware 1.0.4
(updated on 2026-10-25). Since 2026-10-30 it stands at the end of the worktop
next to the oven, facing away from it along the worktop, so the oven is out of
the cone. A kitchen robot stands about 20 cm to its right, unplugged, with no
other place to go; whether it amplifies the noise is untested.

The settings the measurements validated, final since 2026-10-31: the occupancy
timeout at 45 s (lighting hold time; the firmware default is 120 s), zones 1 to
7 enabled, zone 8 disabled and never enabled (undocumented on the device page),
the spatial learning run with the kitchen empty and no appliance in the cone,
and the sensitivity at -1, written after the learning run. Read the live state
with the recipe above rather than trusting this paragraph: a difference is drift
to investigate, a learning run or a power event having rewritten the device, not
an error in the guide.

The placement is the outcome of the first two weeks of measurements. At the
first spot, the other end of the worktop with the oven front at 3 m on the axis,
all zones enabled gave one brief false detection about every seven minutes
through the night of 2026-10-25, 31 in the 5.7 sleeping hours, unrelated to the
fridge's compressor, the oven, or any entity Home Assistant tracks. With zones 5
to 7 disabled an empty window of 49 minutes showed none; with zone 5 alone
re-enabled, three came back in 47 minutes: the source was in the 2.5 to 3 m
band, at the oven, and was never identified. The same spot took in the part of
the room on the left of the cone, so a person walking past the kitchen
registered as present: on the morning of 2026-10-27 the recorder showed 14
episodes of 2 to 30 s of detection (47 to 78 s with the hold) against three
visits of 2 to 4 minutes at the worktop.

The baseline at the new placement failed at sensitivity 0: 48 brief false
detections in the 4.9 empty hours of the evening of 2026-10-30 (9.8 per hour,
steady, no periodicity, the light switched on by every one), after a second
learning run, and still two in six minutes with zones 1 to 4 alone, so the
detections came from every band and the zone bisection had nothing left to find.
Sensitivity -2 (written after the learning run) gave zero detections in the 6
empty hours of the following night; -1 gave zero in an empty window of 1.8 h,
tracked an afternoon of use as 28 visits of up to 40 minutes of continuous
re-triggering, and gave zero in the 7.5 hours of the night of 2026-10-31,
against about 73 expected at the rate of sensitivity 0. The episode lengths tell
the cases apart: a false detection is 47 to 48 s, a walkthrough 55 to 75 s (10
to 30 s of detection plus the hold; two timed crossings read 56 and 57 s), a
visit re-triggers for minutes.

The kitchen light automations in the Home Assistant template consume this
sensor, as the [Home Assistant operations guide](./home-assistant.md) describes.
