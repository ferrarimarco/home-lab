# Design Spec: Monitoring Alerting

## Implementation Status

| Component / Feature              | Status                | Details                                                                                                                       |
| :------------------------------- | :-------------------- | :---------------------------------------------------------------------------------------------------------------------------- |
| **Alertmanager Service**         | **Fully Implemented** | `prom/alertmanager` service in the monitoring backend compose template; deployed and healthy on raspberrypi2 (§3).            |
| **Alertmanager Configuration**   | **Fully Implemented** | Severity-aware routing and the Telegram receiver; end-to-end delivery verified with a synthetic alert (§4, §5).               |
| **Prometheus Alerting Wiring**   | **Fully Implemented** | Rule file loading, the Alertmanager target, and the Alertmanager scrape job; scrape target healthy (§3.2, §7).                |
| **Alert Rules: Availability**    | **Fully Implemented** | `InstanceDown` deployed; surfaced real down targets on first evaluation (§6.1).                                               |
| **Alert Rules: Node Health**     | **Fully Implemented** | Unexpected reboots and node exporter textfile staleness (§6.2).                                                               |
| **Alert Rules: Temperature**     | **Fully Implemented** | Generic CPU temperature, Coral TPU temperature, and Coral sensor failure (§6.3).                                              |
| **Alert Rules: Backups**         | **Fully Implemented** | Restic backup staleness and repository check failures (§6.4).                                                                 |
| **Alert Rules: Blackbox Probes** | **Fully Implemented** | ICMP, DNS, and HTTP probe failures (§6.5).                                                                                    |
| **Restart Policy Migration**     | **Fully Implemented** | All four monitoring backend services run with `restart: unless-stopped`, verified via `docker inspect` after deployment (§8). |

## 1. Goal

Add alerting to the existing Prometheus-based monitoring stack so that known
failure modes are pushed to the operator instead of waiting to be noticed on a
Grafana dashboard. The design deploys Prometheus Alertmanager next to the
existing Prometheus instance, defines a first catalogue of alert rules covering
the gaps identified during past incidents (thermal events, silent
hardware-watchdog recoveries, stale exporters, backup failures, unreachable
targets), and routes notifications to Telegram.

## 2. Rationale

### 2.1 Why Alertmanager

Prometheus already scrapes every signal the known gaps need; what is missing is
evaluation and delivery. Alertmanager is the Prometheus-native component for
that role: rules are evaluated by Prometheus itself from version-controlled rule
files that live and deploy alongside the scrape configuration, while
Alertmanager owns deduplication, grouping, silencing, and delivery.

Rejected alternatives:

- **Grafana-managed alerts**: rejected because alert definitions would live in
  Grafana's database (or a second provisioning pipeline) instead of the same
  templated configuration that defines scraping, and because delivery would
  depend on the dashboard layer being healthy.
- **Home Assistant automations on Prometheus data**: rejected because Home
  Assistant is itself one of the monitored (and historically flaky) workloads;
  the alerting path must not depend on a monitored service.
- **Uptime Kuma or similar standalone watchers**: rejected for this scope
  because they duplicate checks Prometheus already performs; Uptime Kuma remains
  separately tracked in the specs index as a possible complement for external,
  outside-in checks.

### 2.2 Scope

This spec covers the alerting pipeline and the first rules catalogue. It does
not cover new exporters or new metrics: every rule in §6 evaluates data the
stack already collects.

## 3. Architecture

### 3.1 Deployment Model

Alertmanager runs as an additional service in the existing monitoring backend
Docker Compose stack, on the same host as Prometheus and Grafana. It is enabled
by the same mechanism as the rest of the stack (the monitoring backend
enablement flag): a host that runs the monitoring backend runs Alertmanager,
with no separate enablement flag.

Key properties:

- **Pinned image**: the Alertmanager container image is pinned in the
  dependency-updates helper Dockerfile like every other image in the stack, so
  Renovate manages its updates.
- **Persistent state**: Alertmanager stores silences and notification state in a
  dedicated data directory under the monitoring backend runtime data directory,
  so container recreation neither drops active silences nor re-sends
  already-delivered notifications.
- **Host port exposure**: the Alertmanager API and UI are published on host port
  9093 with the same host-local posture as Prometheus on 9090: reached over SSH
  during incident investigation, for `amtool` operations, and for managing
  silences. It is not exposed beyond the host.
- **Restart policy**: `restart: unless-stopped`, together with the rest of the
  stack (§8).

### 3.2 Data Flow

1. Prometheus loads alerting rules from a dedicated, version-controlled rule
   file rendered by the same configuration mechanism that renders
   `prometheus.yaml`, and evaluates them on its global evaluation interval (1
   minute).
2. Firing alerts are sent to Alertmanager over the Compose network.
3. Alertmanager groups, deduplicates, and routes them to the Telegram receiver
   (§4).
4. Prometheus also scrapes Alertmanager's own metrics endpoint, so a dead or
   unhealthy Alertmanager surfaces as a down target (§7).

## 4. Notification Channel

Notifications are delivered to Telegram through Alertmanager's native Telegram
integration, using a dedicated bot and chat.

Rejected alternatives:

- **Webhook into Home Assistant** (reusing its existing Telegram bot): rejected
  because it makes alert delivery depend on Home Assistant, a monitored service
  with known restart and DNS issues; the alerting path must stay independent of
  the systems it watches.
- **SMTP email**: rejected because the lab has no existing mail infrastructure;
  it would add an external dependency and another credential for a slower
  notification channel.
- **Self-hosted push services (ntfy, Gotify)**: rejected because they add a new
  always-on service to operate, and the managed alternative (Telegram) is
  reliable and already in use in the lab.

### 4.1 Secrets

The bot token and chat identifier are secrets and follow the repository secrets
policy: they are stored as vaulted variables in the untracked group-scoped
Ansible vault (`group_vars/all`) and referenced from the Alertmanager
configuration template:

- `vault_monitoring_backend_alertmanager_telegram_bot_token`
- `vault_monitoring_backend_alertmanager_telegram_chat_id`

The rendered configuration file on the host contains the token, matching the
existing posture of the rendered Prometheus configuration, which embeds the Home
Assistant bearer token.

## 5. Routing and Severities

Every rule carries a `severity` label with one of two values:

- **`critical`**: conditions that risk data loss, hardware damage, or an ongoing
  outage (host down, overheating, failed backup integrity check).
- **`warning`**: degradations that need attention but not immediately (stale
  textfiles, aging backups, failing HTTP probes).

Both severities route to the same Telegram receiver; the severity changes the
re-notification cadence, so chronic warnings do not drown urgent alerts:

- Grouping: by alert name and instance, with a short group wait (~30 s) and a
  group interval of ~5 minutes.
- Repeat interval: ~4 hours for `critical`, ~24 hours for `warning`.

### 5.1 Planned Downtime

Hosts that are deliberately powered off (for example a Proxmox node shut down on
purpose) will fire availability alerts. Planned downtime is handled with
Alertmanager silences (via `amtool` over SSH or the UI), not with configuration
changes.

Rejected alternative: a per-host "intermittent" classification in the inventory
that would route availability alerts for such hosts at lower severity. Rejected
for now as premature complexity in a single-operator lab where creating a
silence is a single command; revisit if planned power cycles become frequent
enough that missing silences produce recurring noise.

## 6. Alert Rules Catalogue

Rules are grouped by theme. Conditions are stated as the contract each rule
implements; thresholds and durations are the initial values and may be tuned
with operational experience.

### 6.1 Availability

| Alert          | Severity | Condition | Duration | Rationale                                                                                     |
| :------------- | :------- | :-------- | :------- | :-------------------------------------------------------------------------------------------- |
| `InstanceDown` | critical | `up == 0` | 10 min   | An exporter or host stopped answering scrapes; covers unreachable targets and dead exporters. |

### 6.2 Node Health

| Alert               | Severity | Condition                                          | Duration | Rationale                                                                                                                         |
| :------------------ | :------- | :------------------------------------------------- | :------- | :-------------------------------------------------------------------------------------------------------------------------------- |
| `UnexpectedReboot`  | warning  | `changes(node_boot_time_seconds[1h]) > 0`          | —        | Reboots (including hardware-watchdog recoveries) are noticed instead of silently absorbed.                                        |
| `NodeTextfileStale` | warning  | `time() - node_textfile_mtime_seconds > 26 * 3600` | —        | A textfile collector stopped updating. 26 h covers the slowest producer (the daily apt job); per-collector tuning is future work. |

### 6.3 Temperature

| Alert                     | Severity | Condition                            | Duration | Rationale                                                                                                   |
| :------------------------ | :------- | :----------------------------------- | :------- | :---------------------------------------------------------------------------------------------------------- |
| `HostHighCpuTemperature`  | critical | `node_hwmon_temp_celsius > 85`       | 5 min    | Generic across all scraped hosts, so new hosts are covered automatically; threshold from the pve1 incident. |
| `CoralTpuHighTemperature` | critical | `coral_pci_temperature_celsius > 90` | 5 min    | Coral TPU threshold identified during the August 2026 thermal incident.                                     |
| `CoralTpuSensorFailure`   | warning  | `coral_pci_temperature_celsius < 0`  | 15 min   | The exporter reports `-1` on failed sysfs reads, and a hung device reports implausible negative values.     |

### 6.4 Backups

| Alert                 | Severity | Condition                                      | Duration | Rationale                                                                     |
| :-------------------- | :------- | :--------------------------------------------- | :------- | :---------------------------------------------------------------------------- |
| `ResticBackupStale`   | warning  | `time() - restic_backup_timestamp > 2 * 86400` | —        | No successful backup for two days: early signal before it becomes a real gap. |
| `ResticBackupMissing` | critical | `time() - restic_backup_timestamp > 4 * 86400` | —        | No successful backup for four days: standing data-loss exposure.              |
| `ResticCheckFailed`   | critical | `restic_check_success == 0`                    | —        | The repository integrity check failed; backups may not be restorable.         |

### 6.5 Blackbox Probes

| Alert                     | Severity | Condition                                       | Duration | Rationale                                                                   |
| :------------------------ | :------- | :---------------------------------------------- | :------- | :-------------------------------------------------------------------------- |
| `BlackboxProbeFailed`     | critical | `probe_success == 0` on ICMP and DNS probe jobs | 10 min   | A host does not answer pings, or a DNS record does not resolve as declared. |
| `BlackboxHttpProbeFailed` | warning  | `probe_success == 0` on HTTP probe jobs         | 10 min   | An HTTP endpoint stopped answering with the expected status.                |

> **Known-failing probe:** the Syncthing HTTP endpoint probe currently fails by
> configuration (authentication and self-signed certificate; tracked in the
> specs index issues list). `BlackboxHttpProbeFailed` will therefore fire for it
> from the first deployment. This is accepted: the alert is silenced until the
> probe is fixed, keeping the rule catalogue free of one-off exclusions.

## 7. Alerting Pipeline Health

The pipeline must not fail silently:

- Prometheus scrapes Alertmanager's metrics endpoint, so a dead Alertmanager
  raises `InstanceDown` while Prometheus itself is alive.
- A full dead-man's-switch (an always-firing heartbeat alert delivered through
  an independent channel, catching the case where Prometheus or the whole host
  is down) is deliberately out of scope for this iteration and tracked in the
  specs index.

## 8. Restart Policy Migration

All services in the monitoring backend Compose stack (Prometheus, Grafana, the
Blackbox exporter, and the new Alertmanager) use `restart: unless-stopped`
instead of `restart: always`, so a service stopped deliberately (for example
during a migration or an incident) stays stopped across daemon restarts. This
completes the monitoring backend part of the repository-wide restart policy
migration tracked in the specs index.

## 9. Verification

A deployment of this spec is verified with read-only checks:

- The rendered rule file and Alertmanager configuration validate with the
  `promtool` and `amtool` checkers from the same pinned container images the
  stack runs.
- The Alertmanager and Prometheus health endpoints report healthy, and the
  Prometheus rules API lists every group in the catalogue (§6).
- A synthetic alert posted through the Alertmanager API is delivered to the
  Telegram chat, proving the full routing and credential path.

## Future Work

Future work items are tracked centrally in the
[Specifications to write and TODOs](./README.md#specifications-to-write-and-todos)
section of the specs index.
