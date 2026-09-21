# Monitoring

This guide describes how to operate the home lab monitoring stack, and how to
run ad-hoc checks against it.

The monitoring stack works as follows:

- Each home lab node runs monitoring agents (exporters) that expose metrics
  about the node and the workloads it hosts.
- A Prometheus backend scrapes metrics from the monitoring agents and stores
  them as time series.
- Grafana provides dashboards on top of the data that the Prometheus backend
  collects.
- A Prometheus Blackbox Exporter runs synthetic probes (ICMP, DNS, HTTP) against
  endpoints to verify their availability from the outside.
- A Network UPS Tools (NUT) exporter on hl01 exposes metrics about the UPS,
  querying the NUT server on pve1 (the host the UPS USB interface is physically
  connected to) over the network.
- Prometheus Alertmanager routes firing alerts to Telegram. The
  [Monitoring Alerting specification](../../specs/monitoring-alerting.md)
  describes the design, the severity model, and the alert rules catalogue.

For setup-side tasks, such as importing Grafana dashboards, see
[Configure monitoring](../configure-monitoring.md).

## Alerting

Alertmanager runs in the monitoring backend Docker Compose stack, with its API
and UI published host-locally on port 9093 of the monitoring backend host
(currently raspberrypi2), like the Prometheus API on port 9090. Reach it over
SSH.

Alerts carry a `severity` label: `critical` alerts re-notify about every 4
hours, `warning` alerts about every 24 hours. Both route to the same Telegram
chat.

### Down targets are not necessarily outages

The Prometheus scrape target lists and the blackbox probe target lists are
generated from inventory-wide defaults, so they can include services that were
never deployed on a given host. Before treating a down target as a service
failure, verify on the target host that the service is actually deployed (check
the rendered Docker Compose file under `/etc/ferrarimarco-home-lab/`, or the
host's NixOS configuration): a target that has never been up points to a
configuration gap, not an outage.

### Planned downtime

Deliberately powering off a monitored host (for example a Proxmox node) fires
availability alerts by design. Silence them for the duration of the planned
downtime instead of changing the alert rules:

```shell
ssh pi@raspberrypi2.edge.lab.ferrari.how \
  docker exec alertmanager amtool \
  --alertmanager.url=http://localhost:9093 \
  silence add "instance=~\"pve1.*\"" \
  --duration=4h --author=ferrarimarco --comment="Planned maintenance"
```

List and expire silences with `amtool silence query` and
`amtool silence expire <id>` through the same invocation pattern.

## Prometheus Blackbox Exporter example queries

The Blackbox Exporter exposes a probe endpoint at
`http://<blackbox-exporter-host>:9115/probe`. You can query it directly to run a
probe on demand, which is useful to debug failing checks. Appending `debug=true`
to the query string makes the exporter return the full probe log instead of the
metrics output.

Example queries:

- ICMP ping:

    ```text
    http://<blackbox-exporter-host>:9115/probe?module=icmp&target=raspberrypi.edge.lab.ferrari.how&debug=true
    ```

- DNS A record (ferrarimarco.info):

    - Against an upstream DNS server:

        ```text
        http://<blackbox-exporter-host>:9115/probe?module=dns_ferrarimarco_info_a&target=8.8.8.8&debug=true
        ```

    - Against the DNS resolver:

        ```text
        http://<blackbox-exporter-host>:9115/probe?module=dns_gateway_edge_lab_ferrari_how_a&target=10.0.0.2:8053&debug=true
        ```

- DNS NS record (ferrarimarco.info), against an upstream DNS server:

    ```text
    http://<blackbox-exporter-host>:9115/probe?module=dns_ferrarimarco_info_ns&target=8.8.8.8&debug=true
    ```
