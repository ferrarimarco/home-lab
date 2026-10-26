# Design Spec: MQTT Broker

## Implementation Status

| Component / Feature              | Status                | Details                                                                                                                                                                           |
| :------------------------------- | :-------------------- | :-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **`mosquitto` Nix role on hl02** | **Fully Implemented** | Imported by hl02; comin deployed it on 2026-10-25 and the broker verified from the control machine; the client tools addition awaits its deployment.                              |
| **Integration test check**       | **Fully Implemented** | Generator check (unit, listener ports, retained messages from an anonymous and a named client surviving a restart); passed in the hl02 test on 2026-10-24.                        |
| **Broker TCP probe**             | **Fully Implemented** | `blackbox-tcp` job on `mosquitto_server_fqdn:1883` with `BlackboxTcpProbeFailed`; rules tests pass; applied on both replicas on 2026-10-24, green against hl02 since the cutover. |
| **Consumers on the hl02 broker** | **Fully Implemented** | Frigate and Zigbee2MQTT re-pointed by the playbook run of 2026-10-26, the Home Assistant config entry rewritten the same day; no MQTT entity unavailable afterwards.              |
| **raspberrypi2 broker retired**  | **Fully Implemented** | Torn down on 2026-10-26 by dropping `configure_mqtt_broker` (container, unit, and directories gone); the stack's code removed from the node role the same day.                    |

## Goal

One MQTT broker for the smart home workloads, run as the NixOS
`services.mosquitto` module on [hl02](./proxmox-vm.md) and converged by comin
like the rest of that host, replacing the Compose stack of the
`ferrarimarco_home_lab_node` Ansible role on raspberrypi2.

## Rationale

The broker is the bus between Home Assistant, Frigate, and Zigbee2MQTT: the
Zigbee devices, the camera events, and the automations that react to them all
pass through it, and the availability of every MQTT entity in Home Assistant
follows it. On raspberrypi2 it shared a host whose stalls and disk failure are
recorded in the [specs todo list](./README.md#issues-to-solve), and it was the
last stateless workload keeping that host in the smart home path besides
Zigbee2MQTT, which stays where the Zigbee radio is.

The containers of raspberrypi2 move to hl01 (decided 2026-10-08), but that
decision covered Compose workloads: a native NixOS module is not one, and hl02
is the lab's declarative always-on VM with no other role beyond monitoring and
GitOps. Running the broker there keeps it off the hosts that run the consumers
(hl01 for Home Assistant and Frigate, raspberrypi2 for Zigbee2MQTT), so a
restart of either consumer host does not take the bus down for the other.

## Design

### The `mosquitto` role

`config/nix/roles/mosquitto/default.nix` enables `services.mosquitto` with one
listener on port 1883 and opens that port in the NixOS firewall, which the
module does not do by itself. The listener is open, like the broker it replaces:
the nixpkgs module writes a password file and an ACL file for every listener, so
open access takes `omitPasswordAuth`, `allow_anonymous`, and a
`pattern readwrite #` ACL rule together. Without the rule, clients connect but
are denied every topic, and the rule is a pattern rather than a topic line
because a topic line covers anonymous clients only: a client that presents a
username (the Home Assistant MQTT entry may) would be denied every topic.
Authentication and TLS are a [Security](./README.md#security) todo item, blocked
on a secret delivery path for the NixOS hosts.

Persistence stays on, in the module's data directory under `/var/lib`, so
retained messages (the Home Assistant discovery payloads, the Zigbee2MQTT device
states and bridge information) survive a broker restart without waiting for the
publishers. That store is a cache: every consumer republishes its retained
topics when it reconnects, so it is not part of the backup set.

Logging goes to the journal through the module's default `stderr` destination.

The role also installs the broker package's client tools (`mosquitto_pub`,
`mosquitto_sub`) on the host, so the operations guides read retained topics and
call Zigbee2MQTT's MQTT API from the broker host against localhost, the same
shape the raspberrypi2 recipe had with the container's tools, and independent of
where the consumers run (the
[Zigbee2MQTT operations guide](../guides/operations/zigbee2mqtt.md) has the
recipe).

### Integration test

The [test generator](./declarative-integration-testing.md) adds a check to the
test of every host that enables the broker with a TCP listener: it waits for
`mosquitto.service` and every TCP listener port, publishes a retained message on
the first listener from an anonymous client and another from a client presenting
a username, restarts the broker, and asserts that fresh subscribers receive
both. The restart is what makes this a persistence check: retained messages are
served from memory, and only a clean shutdown writes them to the store the
restart reloads. The named client proves the ACL admits clients with a username.
The generator ships the broker package's client tools into the test machine for
this check only.

### Monitoring

The [monitoring backend](./monitoring-alerting.md) probes the broker with a
Blackbox `tcp_connect` module against the address the consumers use
(`mosquitto_server_fqdn` of the node role) on port 1883, from both replica
hosts, and alerts after ten minutes of failure. Deriving the target from the
same variable the consumers read means the probe always watches the broker the
lab points at, with no second place to update at a move.

### Cutover from raspberrypi2

The deployment is fresh: no state is copied from the raspberrypi2 broker, since
the consumers republish their retained topics on reconnection. Both brokers run
during the cutover, because comin deploys the hl02 side when the role merges
while the consumers still name raspberrypi2. The consumers then move by
re-pointing `mosquitto_server_fqdn` in the node role's `vars/main.yaml` (Frigate
and Zigbee2MQTT read it, and the probe target follows it) and the broker host of
the Home Assistant MQTT integration in its stored config entry, with Home
Assistant stopped, as the
[Home Assistant operations guide](../guides/operations/home-assistant.md)
describes (the entry keeps its ID, so the entities keep their history; the
interface's reconfigure flow is the alternative); the raspberrypi2 stack is torn
down afterwards by dropping `configure_mqtt_broker` from its host variables.
Done on 2026-10-26: both brokers ran side by side for a day, the consumers
reconnected within seconds of their restart, Home Assistant was stopped for
about a minute, and no MQTT entity stayed unavailable. The hl02 static address
of the [Networking](./README.md#networking) todo list is an ordering preference,
not a dependency: the consumers connect by name, which the gateway resolves from
the lease.

## Consumers

| Consumer       | Host         | Where the broker address lives                                                         |
| :------------- | :----------- | :------------------------------------------------------------------------------------- |
| Frigate        | hl01         | `mqtt.host` in the rendered Frigate configuration, from `mosquitto_server_fqdn`.       |
| Zigbee2MQTT    | raspberrypi2 | `mqtt.server` in the rendered Zigbee2MQTT configuration, from `mosquitto_server_fqdn`. |
| Home Assistant | hl01         | The MQTT integration's config entry (`broker` in its `data`), not in the templates.    |
