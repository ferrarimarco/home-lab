# Home Assistant operations

Home Assistant runs on hl01 as the `homeassistant` service of the
`home-assistant` Compose stack, with its configuration under
`/etc/ferrarimarco-home-lab/home-assistant/config`. Its state can be read from
that directory without an API token, which is how the checks below work.

## Read entity, device, and integration state

The `.storage` directory holds JSON registries, readable as root:

- `core.entity_registry`: every entity with its `platform`, `unique_id`, and
  `device_id`; MQTT-discovered entities have `platform: mqtt`.
- `core.device_registry`: devices with their `identifiers`; Zigbee2MQTT devices
  carry `["mqtt", "zigbee2mqtt_<ieee>"]`.
- `core.config_entries`: integrations with their settings, including the URL or
  address an integration polls. The repository does not manage them, and a stale
  one logs a connection error at every poll.
- `core.restore_state`: the last state of every entity, written periodically and
  at shutdown; enough for a quick look without touching the database.

After a workload moves hosts, list the integrations that still name the old host
(the Compose project directory holds the configuration):

```shell
sudo python3 -c '
import json, sys
old = sys.argv[1]
for e in json.load(open("/etc/ferrarimarco-home-lab/home-assistant/config/.storage/core.config_entries"))["data"]["entries"]:
    if old in json.dumps(e["data"]): print(e["domain"], e["title"], e["data"])
' <old host name>
```

Re-point each one in the interface (Settings, Devices and services, the
integration, Reconfigure, where the integration offers it; otherwise remove and
re-add it). An integration with neither flow, such as the Network UPS Tools
server address, can be edited in `core.config_entries` directly with Home
Assistant stopped, then started again.

Current entity states are in the recorder database, which SQLite keeps in
write-ahead mode: copy `home-assistant_v2.db` together with its `-wal` and
`-shm` files to a temporary directory, query the copy, and delete it. A copy
taken while the recorder writes can be inconsistent; retry if the query fails.

```sql
-- Latest recorded state of every entity
SELECT m.entity_id, s.state, s.last_updated_ts
FROM states s JOIN states_meta m ON s.metadata_id = m.metadata_id
WHERE s.state_id IN (SELECT MAX(state_id) FROM states GROUP BY metadata_id);
```

Counting the MQTT entities whose latest state is `unavailable` is the check that
tells whether an MQTT-side change reached Home Assistant; `unknown` is the
normal state of entities that have no value until used (effect settings, the
network map).

## MQTT discovery updates and availability

On a discovery update Home Assistant re-subscribes only the topics that changed
and keeps the availability it already holds per topic (verified in the MQTT
integration of 2026.8.3). When a publisher changes the availability payload
format, as Zigbee2MQTT 2.x did by switching from `online` to
`{"state":"online"}`, entities discovered under the old format stay
`unavailable` until a new availability message arrives, while entities
discovered after the change work. Make every entity subscribe afresh, so the
broker redelivers the retained messages: restart Home Assistant (the verified
path on 2026-10-17), or reload the MQTT config entry from the menu of its entry
row under Settings, Devices and services, which the interface offers for
integrations that support unloading (expected to have the same effect, not
tried). The `mqtt.reload` action is not an alternative: it reloads only
YAML-configured entities.

```shell
sudo docker compose --file /etc/ferrarimarco-home-lab/home-assistant/compose.yaml restart homeassistant
```

Entities whose discovery config the publisher cleared are removed by Home
Assistant on its own; compare the registry with the retained `homeassistant/#`
topics on the broker to confirm nothing is orphaned.
