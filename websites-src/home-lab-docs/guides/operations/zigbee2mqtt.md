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
   the sensor, a source, or a shield on the head, since a stale profile reads as
   false detections until the next run. The device reports raw detections while
   it learns, and they reach the consumers like any other state: disable the
   automations for the run or accept a flash of the light. On firmware 1.0.4 of
   the SNZB-06P24 the run also resets the sensitivity to 0 without a message in
   the log: read the state back after every run.
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
9. Shield what no zone excludes. The zones are radial, so a target in the same
   band as the covered area on another bearing (a table beside the end of a
   worktop) comes out only by narrowing the cone on that side: a strip of
   household aluminium foil along that side of the head blocks the 24 GHz beam,
   which passes wood, plastic, and plasterboard, while a yaw of the head moves
   the whole cone. Fit it, run the learning again, then test the covered
   positions and the excluded ones for about two minutes each, and a real meal:
   one still person at a seat is an easier case than a group, and a position
   that passes the first fails the second.

The sensor ships without a power supply, and a faulty USB charger is a confirmed
failure cause rather than a source of brief triggers: on 2026-10-30 the kitchen
sensor dropped off the network with occupancy held true, so the light it had
switched on stayed on, because the off automation triggers on the change to
clear and the entity went unavailable instead. Another candidate for random
brief triggers, not confirmed: the cooling fan an oven runs after switch-off,
which the learning run does not cover when it ran with the oven on.

## Kitchen presence sensor

The sensor named "Presenza cucina" is a Sonoff SNZB-06P24 on firmware 1.0.4. It
stands at the end of the worktop next to the oven, facing away from it along the
worktop, so the oven is out of the cone: at the other end of the worktop, with
the oven front at 3 m on the axis, something in the oven's direction gave a
brief false detection about every seven minutes through the night, and the cone
took in the walkway beside the kitchen. A kitchen robot stands about 20 cm to
its right, unplugged, with no other place to go.

The settings, final since 2026-11-10, each with its reason:

- The occupancy timeout at 45 s: the lighting hold time; the firmware default is
  120 s.
- Zones 1 to 4 enabled, 5 to 8 disabled: the worktop is an L 60 cm deep, 2.30 m
  along the sensor's axis and 2.10 m on the short arm, so every working position
  lies within 2.5 m and the far bands cover only the room beyond; the walk-by
  episodes were people moving inside the kitchen, so the far bands were never
  the fix for them. Zone 8 is undocumented on the device page and was never
  enabled.
- A foil blinder on the right side of the head, as step 9 describes: the dining
  table's seats at 2.0 to 2.4 m lie in the same band and on the same side as the
  end of the short arm, so no zone or sensitivity setting excludes them (four
  dinners held occupancy for 40 to 90 percent of the seated time at every
  setting tried), and the head was already turned away from the table as far as
  its mount allows. The foil took three positions to clear the farthest seat at
  a meal: a position that passes one still person at a seat can fail a group.
- The spatial learning run with the kitchen empty, no appliance in the cone, and
  the blinder in place, repeated after every move of the foil: a stale profile
  held occupancy for 45 of 53 empty minutes.
- The sensitivity at -1, written after the learning run (on firmware 1.0.4 the
  run resets it to 0): 0 gave about ten brief false detections an hour from
  every band, -1 and -2 gave none through the night, and -3 would cost detection
  at the worktop.

The zone flags are the `enable_occupancy_zone_<n>` properties and the learning
command is `spatial_learning` with the value `start_learning`: a guessed name
(`zone_4`) is refused with "No converter available" in the log. Read the live
state with the recipe above rather than trusting this list: a difference is
drift to investigate, a learning run or a power event having rewritten the
device, not an error in the guide.

With the 45 s timeout the episode lengths tell the cases apart: a false
detection lasts 47 to 48 s, a crossing 55 to 75 s (10 to 30 s of detection plus
the hold), and a visit re-triggers for minutes.

The kitchen light automations in the Home Assistant template consume this
sensor, as the [Home Assistant operations guide](./home-assistant.md) describes.
