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

For setup-side tasks, such as importing Grafana dashboards, see
[Configure monitoring](../configure-monitoring.md).

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
