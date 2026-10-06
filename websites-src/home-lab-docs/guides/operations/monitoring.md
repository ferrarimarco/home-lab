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
- Prometheus scrapes Frigate's native metrics endpoint (`/api/metrics`) on the
  hosts that run Frigate, covering the per-camera capture pipeline and the
  object detector, which stay invisible to the container healthcheck and the
  HTTP probe of the Frigate user interface.
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

## Interpreting query results

- **A gap in `query_range` samples is a state change.** `ALERTS` series exist
  only while an alert is pending or firing, so summarizing a range by
  compressing sample values without splitting on gaps reports an alert as
  continuously firing when it resolved mid-window. The same applies to `up` and
  probe series after a configuration change removes their target.
- **Instant queries look back five minutes for the latest sample** (the default
  lookback delta). A live configuration reload writes staleness markers for a
  removed target's series, so they disappear quickly; a Prometheus restart does
  not, so after a restart-applied scrape-configuration change (how this stack
  deploys them), removed targets linger in instant results for up to five
  minutes.
- **PromQL set operators match on full label sets, ignoring the metric name.**
  `a or b` suppresses right-hand series whose labels match a left-hand series,
  so enumerating several metrics in one `or` chain silently drops some: query
  each metric separately instead.

### Auditing alert coverage

To find unalerted signals, diff the scrape jobs against the alert rule file's
groups: `count by (job) (up)` lists every job with at least one scraped target
(up or down), a configured job missing from the result rendered zero targets,
and each job without a corresponding rule group is a candidate gap. Verify every
candidate rule expression against the metric names actually present in the TSDB
before writing it: exporters rename and re-label metrics between versions.

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
