# Home Assistant operations

Home Assistant runs on hl01 as the `homeassistant` service of the
`home-assistant` Compose stack, with its configuration under
`/etc/ferrarimarco-home-lab/home-assistant/config`. The node role renders
`configuration.yaml` and `automations.yaml` there from its templates on every
run, so an automation is fixed in the template (and reloaded with a restart),
not in the live file alone. Its state can be read from that directory without an
API token, which is how the checks below work.

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
integration, Reconfigure, where the integration offers it). Without that flow,
edit the stored entry as described next: removing and re-adding the integration
also works but gives its entities new identities and drops their history.

## Change an integration's settings without a reconfigure flow

Home Assistant reads `core.config_entries` only at startup, so the entry of any
integration can be edited with Home Assistant stopped; the entry keeps its ID,
so its entities keep their identities and history. Done for the qBittorrent URL
on 2026-10-18 (its config flow has only the setup step) and, earlier, for the
Network UPS Tools server address (a host and a port in the entry's `data` block;
qBittorrent stores a single `url`).

1. Stop the container:
   `sudo docker compose --file /etc/ferrarimarco-home-lab/home-assistant/compose.yaml stop homeassistant`.
1. Keep a root-only copy of the file under `/root` (it holds every integration's
   secrets, so the copy stays on the host): `sudo cp -p` then `sudo chmod 0600`.
1. Rewrite the field in the entry's `data` block with a script that loads the
   JSON, changes exactly one entry (assert on the count), and writes it back
   with two-space indentation, which is how Home Assistant formats it; then
   check that the file still parses.
1. Start the container the same way, wait for the interface to answer, and
   verify: the integration's errors stop in the container log, and its entities
   report values in the recorder (the query above) within its first poll
   interval.

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
topics on the broker to confirm nothing is orphaned. The same release dropped
the legacy entity attributes (the device's whole payload on every entity), so an
automation or template that reads an attribute of a Zigbee2MQTT entity stops
silently: check the automations template for `attribute:` on MQTT entities (the
studio gaming rig automation triggered on the power sensor's `power` attribute
and went quiet after the 2026-10-17 upgrade).

## Read history from the recorder database

The recorder keeps every state change in the SQLite database next to the
configuration, which is the house-wide history a correlation needs (which
entities changed around the events of a sensor). Open it read-only from the host
with Python's `sqlite3` module, which the host has and the container does not
need:

```shell
sudo python3 - <<'PY'
import sqlite3, datetime
db = sqlite3.connect(
    "file:/etc/ferrarimarco-home-lab/home-assistant/config/home-assistant_v2.db?mode=ro",
    uri=True)
t0 = datetime.datetime(2026, 10, 26, 0, 0, tzinfo=datetime.timezone.utc).timestamp()
t1 = datetime.datetime(2026, 10, 26, 6, 0, tzinfo=datetime.timezone.utc).timestamp()
query = """select m.entity_id, s.state, s.last_updated_ts
    from states s join states_meta m on s.metadata_id = m.metadata_id
    where s.last_updated_ts between ? and ? order by s.last_updated_ts"""
for entity_id, state, ts in db.execute(query, (t0, t1)):
    print(datetime.datetime.fromtimestamp(ts, datetime.timezone.utc), entity_id, state)
PY
```

Timestamps are Unix seconds in UTC. A heredoc piped through SSH mangles the `%`
of a `like` pattern; pass the script as a file (base64 through the SSH command
works) when the query needs one.

## Automations that respect manual control

Every state change carries a context that tells its origin: a change made by an
automation has a `parent_id`, one made from the interface has a `user_id`, and
one a device pushes after a physical switch flip has neither. Template state
objects expose it (the `context` property of the template state class in
`homeassistant/helpers/template/states.py`, verified at 2026.9.4), so an
automation that turns a light off when a room clears can leave alone a light
that was switched on by hand or from the app with one condition and no helper
entity:

```yaml
- condition: template
  value_template: "{{ states.switch.<light>.context.parent_id is not none }}"
```

The kitchen light automations in the automations template use it: occupancy from
the kitchen presence sensor (the
[Zigbee2MQTT operations guide](./zigbee2mqtt.md) records its settings) turns the
Shelly relay on when the light is off and the kitchen is dark, and the clear
state turns it off only when an automation turned it on. Two limits, both of
which leave a light on rather than switch one off: a wall flip while the
automation already holds the light on changes no state and goes unnoticed, and a
restart gives restored states a fresh context, so a light the automation turned
on before the restart counts as manual afterwards. The Shelly's input mode
matters too: in `follow` mode the relay copies the wall switch position, so
after the automation has turned the relay off the next flip does nothing visible
and a second one is needed, while `flip` mode toggles the relay on every flip;
the mode is a setting on the device, not in the repository.
