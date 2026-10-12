# Monitoring

To monitor the status of the home lab, the automated provisioning and
configuration process deploy a monitoring agent on each home lab node, and a
backend to collect data coming from the monitoring agents.

## Import Grafana dashboards

In its current state, Grafana doesn't support automatic import of dashboards
that a datasource ships, so you need to import those dashboards manually. To
import Grafana dashboards that ship with a datasource, do the following:

1. Open Grafana.
2. Open the datasource settings.
3. Select a datasource.
4. Open the `Dashboards` panel.
5. Import the dashboards.

## Provisioned dashboards

The monitoring backend provisions the dashboards under
`config/ansible/roles/ferrarimarco_home_lab_node/files/config/monitoring-backend/grafana/dashboards/dashboard-definitions/`
from files (`allowUiUpdates: false`, `disableDeletion: true`), so a dashboard is
edited by exporting it from the Grafana UI and committing the export. Grafana 13
accepts both the classic JSON model and the v2 resource
(`apiVersion: dashboard.grafana.app/v2`); for a v2 export keep `metadata` down
to `name` (the dashboard uid) and drop the instance fields the UI adds
(`resourceVersion`, `generation`, timestamps, creator and updater annotations).

### The provisioner refuses a file

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
UI because the failed saves mark it as file-managed too. Confirm it from a copy
of the database (read-only; the host has no `sqlite3` binary, Python does):

```shell
docker cp grafana:/var/lib/grafana/grafana.db /tmp/grafana-inspect.db
python3 - <<'EOF'
import sqlite3
c = sqlite3.connect("/tmp/grafana-inspect.db")
print(c.execute("select dashboard_id, external_id from dashboard_provisioning").fetchall())
print(c.execute("select id, uid, title from dashboard where is_folder = 0").fetchall())
EOF
rm /tmp/grafana-inspect.db
```

Fix the file, not the database: set the file's uid (`uid` in the classic model,
`metadata.name` in the v2 resource) to the uid of the dashboard the provisioning
record points at, and apply the monitoring-backend stack. The APT dashboard sat
in that state from 2025-05-31 to 2026-10-12 on both backends.

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
