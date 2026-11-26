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
  [Monitoring Alerting specification](../../architecture/monitoring-alerting.md)
  describes the design, the severity model, and the alert rules catalogue.

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

Size a silence past the alert's own duration, not just past the maintenance:
`UnexpectedReboot` fires for an hour after the boot, so a one-hour silence added
right before a reboot expires in the same minute the alert resolves (hl01,
2026-10-22, the first planned reboot with a silence). Probe alerts carry the
probed target as their instance, so a host silence misses them: add a second
silence on their alert names (`alertname=~"Blackbox.*|Frigate.*"`), since the
matchers within one silence are ANDed and anchored. A reboot of a monitoring
replica, or of the node that hosts one, also raises
`PrometheusNotificationsErroring` on the replica that stays up, which looks back
15 minutes: silence it by its alert name for the reboot plus 20 minutes, and add
every silence on the replica that stays up. The suppressed alerts and the
notifications sent are visible in Prometheus as
`alertmanager_alerts{state="suppressed"}` and
`alertmanager_notifications_total{integration="telegram"}`.

### Did the alerts reach Telegram

Telegram delivery needs the WAN (the
[alerting spec](../../architecture/monitoring-alerting.md) covers the
consequence), so after a WAN outage read the delivery attempts of the window
from the Alertmanager container log on either replica:

```shell
ssh pi@raspberrypi2.edge.lab.ferrari.how \
  docker logs --since 2026-11-04T01:30:00Z --until 2026-11-04T06:20:00Z \
  alertmanager 2>&1 | grep -E 'Notify'
```

In Alertmanager 0.34: an error line "Notify for alerts failed" whose `err` says
"notify retry canceled after N attempts" means the group was dropped until its
next group interval; a warning "Notify attempt failed, will retry later" is
logged when the error text changes, with the attempt count in its `attempts`
field; "Notify success" is logged at the default level only for a delivery that
needed retries, so an absent line is not a missed delivery. Count the deliveries
with `alertmanager_notifications_total{integration="telegram"}`.

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
before writing it: exporters rename and re-label metrics between versions. Give
every new rule a unit test, as the
[operational scripts guide](../development/operational-scripts.md#testing)
describes.

### Testing a rule against a past failure

A rule written for a failure that was just fixed can still be seen firing on the
replicas, without recreating the failure: pin the side of its expression that
the fix changed to a time before the fix with the `@` modifier
(`<selector> @ <Unix time>`, from `date -u -d '<time>' +%s`), give it a hold of
a few seconds, and deploy it. First evaluate the pinned expression through the
query API on each replica, passing it on the standard input
(`--data-urlencode query@-`) so that no shell expands a `$1` in it. Once the
alert has fired and its notification is counted (the queries of the planned
downtime section), remove the pin, set the real hold, and deploy again.
`SmartDiskUnmonitored` was tested this way on 2026-11-18, the collector's series
pinned to a time before the disk had any.

### A disk without SMART series

The SMART collector of the Proxmox nodes (the `smartmon.sh` script of Debian's
collectors package) lists the disks with `smartctl --scan-open`, and the SMART
rules read what it exports, so a disk the scan leaves out has no series for
them: `SmartDiskUnmonitored` fires for it after an hour. smartmontools picks the
protocol that reaches a disk behind a USB bridge from its drive database, by the
bridge's USB ID, and leaves a disk behind an unknown bridge out of the scan
(`smartctl -i <device>` then prints "Unknown USB bridge" with the ID). To find
such a disk, compare the scan with the disks the host has:

```shell
smartctl --scan-open
lsblk --scsi --output NAME,TRAN,VENDOR,MODEL
```

Try the device types by hand (`smartctl -d sat -i -H <device>`; `sat` is the
standard pass-through). A local database entry then tells the scan which type to
use; test one before declaring it, without writing anything, by feeding it on
the standard input:

```shell
printf '%s\n' '{ "USB: <description>; ", "0x<vendor>:0x<product>", "", "", "-d sat" },' \
  | smartctl --drivedb=+/dev/stdin --scan-open
```

Declare the bridge in the host's `monitoring_smartmontools_usb_bridges` list,
which the monitoring role renders as `/etc/smart_drivedb.h` (pve1 declares the
enclosure of its media disk), and apply the monitoring playbook with a host
limit. An updated database (`update-smart-drivedb`) only helps when upstream
knows the ID, which it did not for that enclosure on 2026-11-18.

### Metrics from the textfile collector

Some metrics arrive through the node exporter textfile collector rather than
exporters. Its directory is `/var/lib/node_exporter/textfile_collector` on the
Debian workload hosts and `/var/lib/prometheus/node-exporter` on the Proxmox
nodes, which run the packaged node exporter. The Debian workload hosts write
`apt_info.prom` (pending updates, reboot-required, written by the
`monitoring-apt` systemd timer) and `smartctl.prom` (SMART health) there, the
nodes `apt.prom` and `smartmon.prom`, and both add host-specific files such as
the ONT exporter's or a restic job's. A stale modification time on one of these
files means its producing unit is broken even if the metric still appears in
Prometheus.

## Grafana dashboards

### Import Grafana dashboards

In its current state, Grafana doesn't support automatic import of dashboards
that a datasource ships, so you need to import those dashboards manually. To
import Grafana dashboards that ship with a datasource, do the following:

1. Open Grafana.
2. Open the datasource settings.
3. Select a datasource.
4. Open the `Dashboards` panel.
5. Import the dashboards.

### Provisioned dashboards

The monitoring backend provisions the dashboards under
`config/ansible/roles/ferrarimarco_home_lab_node/files/config/monitoring-backend/grafana/dashboards/dashboard-definitions/`
from files (`allowUiUpdates: false`, `disableDeletion: true`), so a dashboard is
edited by exporting it from the Grafana UI and committing the export. Grafana 13
accepts both the classic JSON model and the v2 resource
(`apiVersion: dashboard.grafana.app/v2`); for a v2 export keep `metadata` down
to `name` (the dashboard uid) and drop the instance fields the UI adds
(`resourceVersion`, `generation`, timestamps, creator and updater annotations).

A dashboard file reaches the hosts only once it is listed in
`monitoring_backend_files_to_configure` in the node role's `vars/main.yaml`: a
file in the directory alone is never copied, and the Nix comin dashboard sat
unlisted, with a copy imported through the UI on both backends, until
2026-10-23. The provisioner adopts a dashboard imported through the UI when the
file carries its uid: the first pass after the file lands rewrites it as
file-managed, so such a copy needs no cleanup before its file is listed.

Grafana 13 stores the dashboards in the unified storage `resource` table (group
`dashboard.grafana.app`, `name` is the uid) and records the provisioning state
in the `grafana.app/managedBy`, `grafana.app/sourcePath`, and
`grafana.app/sourceChecksum` annotations of each resource. The legacy
`dashboard` and `dashboard_provisioning` tables are no longer updated, so they
report stale versions and miss adoptions. Read the state from a copy of the
database (read-only; the host has no `sqlite3` binary, Python does) and compare
the checksum with `md5sum` of the file on the host; a dashboard migrated from
the legacy tables carries the bare filename as its source path:

```shell
docker cp grafana:/var/lib/grafana/grafana.db /tmp/grafana-inspect.db
python3 - <<'EOF'
import json
import sqlite3
c = sqlite3.connect("/tmp/grafana-inspect.db")
for name, value in c.execute("select name, value from resource where resource = 'dashboards'"):
    a = json.loads(value)["metadata"].get("annotations", {})
    print(name, a.get("grafana.app/managedBy"), a.get("grafana.app/sourcePath"), a.get("grafana.app/sourceChecksum"))
EOF
rm /tmp/grafana-inspect.db
```

#### The provisioner refuses a file

Grafana polls the files every 100 seconds, so a refused file shows up as a
repeating error in the container log:

```shell
docker logs grafana --since 1h 2>&1 | grep "failed to save dashboard"
```

`A dashboard with the same uid already exists` means the uid in the file is not
the uid of the dashboard the provisioner's record owns, but one of another
dashboard (typically a copy imported through the UI, whose export then replaced
the file). The provisioner never updates the dashboard in that state, so the UI
keeps showing stale content, and the clashing copy becomes undeletable from the
UI because the failed saves mark it as file-managed too. Confirm it with the
resource listing above: two resources carry the same `sourcePath`, or the file's
uid is not the one whose `sourcePath` names the file.

Fix the file, not the database: set the file's uid (`uid` in the classic model,
`metadata.name` in the v2 resource) to the uid of the dashboard whose
`sourcePath` annotation names the file, and apply the monitoring-backend stack.
The APT dashboard sat in that state from 2025-05-31 to 2026-10-12 on both
backends.

The orphaned copy cannot be removed through Grafana: the UI, the legacy
dashboard API (`DELETE /api/dashboards/uid/<uid>`), and the resource API (a
patch removing the `grafana.app/managedBy` annotation) all answer that a
provisioned dashboard cannot be deleted or modified, since the failed saves
marked the copy as file-managed. It also blocks provisioning in a second way:
the failed saves stored it under the provisioned dashboard's internal ID, so the
provisioner's lookup finds two dashboards for that ID. Remove it from the
database, with Grafana stopped and the database backed up first:

1. Stop Grafana alone
   (`docker compose -f /etc/ferrarimarco-home-lab/monitoring-backend/compose.yaml stop grafana`)
   and copy `grafana.db` aside in its data directory
   (`/var/lib/ferrarimarco-home-lab/monitoring-backend/grafana`).
2. Delete the copy's rows with Python's `sqlite3`: the `dashboard` row and its
   `dashboard_version` rows (by dashboard ID), and the `resource` and
   `resource_history` rows (by `name`, the uid, with `resource = 'dashboards'`).
   Nothing else references a plain dashboard; check `dashboard_tag`, `star`, and
   `dashboard_acl` for the ID anyway.
3. Move the persisted search index aside (`unified-search` in the data
   directory): at start Grafana otherwise logs "Skipping index build, using
   existing index" and keeps serving the deleted dashboard from it, so the
   provisioner still finds two. With the directory gone it logs "Building index
   using filesystem" and rebuilds from the database.
4. Start Grafana and confirm, from the log, "finished to provision dashboards"
   with no "failed to save dashboard" after it, and, from a fresh database copy,
   that the stored resource carries the file's content.

The 2026-10-12 cleanup of the APT dashboard on both backends followed exactly
these steps; the backups stay in the data directory with a `.bak-2026-10-12`
suffix.

## Reading the state of the ONT

For the state of the ONT during or after an incident, read the exporter's series
in Prometheus first: `ztef6005ont_gpon_status`, whose `Operation state(O5)` flag
is the operational state and which the `OntMetricsMissing` and
`OntGponNotOperational` rules watch, and the optical power series.
`ztef6005ont_uptime_seconds` is the time since the ONT's last boot, so a reset
of the series dates a power cycle or a reboot.
`ztef6005ont_read_duration_seconds` is the time the admin interface took to
answer the exporter's last read, and `ztef6005ont_login_duration_seconds` the
time its last login took, with the TLS handshake of a new connection: the
exporter logs in only when it starts or loses its session, so restart its unit
to take a sample. The ONT row of the Home network dashboard in Grafana shows
these series.

The ONT's own admin interface cannot explain an outage after the fact: the
[ONT notes](../../archive/ont-connection-instability.md#the-2026-11-04-hang)
record what it serves and what it lacks. For a live read, reach it at
`https://192.168.1.1/` through the gateway's NAT rule and log in the way the
exporter does
(`config/ansible/roles/ferrarimarco_home_lab_node/files/config/monitoring-ont/zte-f6005-ont-exporter.py`).
The [archived access notes](../../archive/zte-ont-access.md) describe the route.

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
