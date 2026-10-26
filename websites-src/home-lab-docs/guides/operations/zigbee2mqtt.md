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
The device page on the Zigbee2MQTT site
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
   the sensor or a source, and after changing the sensitivity. The device
   reports raw detections while it learns, so ignore those.
5. Measure before tuning anything else. A false detection reads as one trigger
   followed by the timeout, never re-triggered, while a real visit re-triggers
   and lasts longer. Count the brief ones over a window the room is known to be
   empty, the night, and compare the rate with the candidates: a plug's power
   readings for an appliance, and the house's entity history for everything
   else, ranked against what chance gives (a reading that changes every minute
   lands within a minute of any event). A window of T hours is clean by luck
   with probability e^(-rT) at a background rate of r per hour: 40 minutes at
   5.5 per hour leaves 2.5 percent, enough to decide.
6. Locate the source with the zones. The zones are radial distance bands, so
   disabling one blinds it across the whole cone. Disable the far bands, test an
   empty window, then re-enable them one at a time with a window each; the band
   that brings the detections back holds the source.
7. Change the sensitivity last, one or two steps at a time, because it
   invalidates the learned profile and the measurements above.

Two more candidates for random brief triggers, not confirmed on the kitchen
sensor: a USB power supply with ripple (the sensor ships without one) and the
cooling fan an oven runs after switch-off, which the learning run does not cover
when it ran with the oven on.

## Kitchen presence sensor

The sensor named "Presenza cucina" is a Sonoff SNZB-06P24 on firmware 1.0.4
(updated on 2026-10-25). It stands on the worktop, about 0.9 m high, facing
along the worktop: the oven front sits at 3 m on the axis behind a wooden panel,
a wall closes the right side of the cone, and the rest of the room is on the
left.

| Setting                   | Value                                  | Reason                                            |
| ------------------------- | -------------------------------------- | ------------------------------------------------- |
| Occupancy timeout         | 45 s                                   | lighting hold time; the firmware default is 120 s |
| Sensitivity               | 0                                      | never changed, so the learned profile stays valid |
| Zones 1 to 4 (0 to 2.5 m) | enabled                                | the worktop and the near part of the room         |
| Zones 5 to 7 (2.5 to 4 m) | disabled                               | see below                                         |
| Spatial learning          | run on 2026-10-25 with the oven fan on | filters the fan: 30 minutes clean with it running |

With all zones enabled the sensor reported one brief false detection about every
seven minutes through the night of 2026-10-25, 31 in the 5.7 sleeping hours,
unrelated to the fridge's compressor, the oven, or any entity Home Assistant
tracks. With zones 5 to 7 disabled an empty window of 49 minutes showed none;
with zone 5 alone re-enabled, three came back in 47 minutes. The source is
therefore in the 2.5 to 3 m band, at the oven, and has not been identified: the
follow-up is in the todo list of the
[specs index](../../architecture/README.md). The kitchen light automations in
the Home Assistant template consume this sensor, as the
[Home Assistant operations guide](./home-assistant.md) describes.
