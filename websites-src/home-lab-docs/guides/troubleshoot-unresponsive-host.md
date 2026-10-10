# Troubleshoot an unresponsive host

Runbook for investigating a home lab host that froze, crashed, or stopped
accepting connections, after it has been recovered, or that will not finish
booting (typically by a power cycle). The goal is a defensible timeline and
root-cause hypothesis; "silent freeze with no precursors" is a valid conclusion
when the evidence supports nothing stronger. This runbook was distilled from the
raspberrypi2 freeze investigation of 2026-09-13.

## Establish the timeline

```shell
uptime
last -x reboot shutdown | head
journalctl --list-boots | tail
journalctl -b -1 --no-pager | tail -50
```

- The end timestamp of the previous boot's journal is the last moment the host
  was alive enough to log.
- An abrupt journal end mid-routine-activity, with no shutdown sequence,
  indicates a hard freeze; an orderly shutdown sequence points elsewhere.
- Narrow the death window using periodic activity as a clock: home lab hosts run
  recurring systemd timers (for example `asuswrt-chkwan` every 3 minutes on
  raspberrypi2), so the first missing run bounds the freeze to within one
  period.

## Sweep for precursors

```shell
journalctl -b -1 -p err --no-pager
journalctl -b -1 -k --no-pager | grep -iE "voltage|throttl|oom|hung|I/O error|BUG|Oops|segfault"
ls /sys/fs/pstore/ /var/lib/systemd/pstore/
sudo smartctl -H -A /dev/sdX
```

Separate chronic noise (errors repeating for days) from anything that first
appears near the death window. On Raspberry Pi hosts, also check
`vcgencmd get_throttled` and `sudo vclog --msg`; the throttle flags are sticky
within a boot but reset by a power cycle.

## Query the monitoring history

The Prometheus backend runs on `raspberrypi2.edge.lab.ferrari.how` (port `9090`,
not exposed beyond the host). Query the recorded history over SSH to reconstruct
the state leading up to the incident:

```shell
ssh pi@raspberrypi2.edge.lab.ferrari.how \
  'curl -sf "http://localhost:9090/api/v1/query_range?query=node_thermal_zone_temp{instance=~\".*raspberrypi2.*\"}&start=2026-09-13T11:30:00Z&end=2026-09-13T12:45:00Z&step=120"'
```

Useful series for a pre-crash timeline:

- `node_thermal_zone_temp`, `node_hwmon_temp_celsius`: thermal state.
- `node_load1`, `node_memory_MemAvailable_bytes`: load and memory pressure.
- The timestamp of an instance's last successful scrape independently bounds
  when the host died.

Normal metrics until the end are evidence too: they rule out thermal runaway,
memory exhaustion, and load storms. Note that timestamps in the Prometheus API
are UTC, while host logs (`journalctl`) print local time.

Some metrics arrive through the node exporter textfile collector
(`/var/lib/node_exporter/textfile_collector/` on each host) rather than
exporters: `apt_info.prom` (pending updates, reboot-required, written by the
`monitoring-apt` systemd timer on Debian hosts), `smartctl.prom` (SMART health),
and host-specific files such as the ONT exporter's. A stale modification time on
one of these files means its producing unit is broken even if the metric still
appears in Prometheus.

## Check recovery-boot health

```shell
dmesg | grep -iE "ext4|recover|orphan|error"
systemctl --failed
docker ps --format '{{.Names}}\t{{.Status}}'
```

Filesystem journal recovery and orphan-inode cleanup confirm the stop was
unclean. Confirm all expected workloads restarted.

## Boot stalls in emergency mode

A host that stops answering pings after a reboot, with no SSH, may be stuck at
systemd's emergency prompt rather than dead: an fstab entry without `nofail`
whose device never appears (a failed data disk) fails `local-fs.target` after
the device timeout (90 seconds by default), and on Raspberry Pi OS the locked
root account turns the prompt into "cannot open access to console, the root
account is locked". Networking never comes up, so nothing is reachable. Confirm
on an attached display: the console shows the emergency message, and the systemd
messages above it (`Timed out waiting for device ...`,
`Dependency failed for ...`) name the device. Pressing Enter re-runs the start
job and lands back at the prompt while the device is still missing (observed
2026-10-09), so the console is no way out.

Recovery needs another boot medium: the network-boot rescue once the
[Network Boot Service](../specs/network-boot.md) exists, otherwise a
hand-written rescue SD card. Boot it, mount the host's root filesystem, and edit
its `etc/fstab` so the entry carries `nofail,x-systemd.device-timeout=10` or is
removed, then boot from the host's own disk again. The inventory entry in
`disks_to_mount` must change the same way, or the next playbook run re-renders
the line without `nofail`. Unplug the failed disk before any of these reboots: a
USB disk that resets every few seconds stalls udev and provokes UAS aborts on
the other disks of the same controller, the root disk included.

## Report and remediate

- State the death window and the evidence for it, and list what the incident was
  **not** (thermal, OOM, undervoltage, disk I/O) with the checks that rule each
  out.
- A silent hard freeze at normal load and temperature typically leaves no trace.
  Candidate causes worth listing as hypotheses: power transient, USB or firmware
  lockup, aging kernel.
- Propose resilience fixes (hardware watchdog via `RuntimeWatchdogSec`, so the
  host self-recovers) separately from root-cause fixes (kernel and OS upgrades,
  hardware replacement).
- Record secondary findings (failing disks, broken units, stale textfile
  exporters) even when unrelated: this investigation surfaced a disk with
  pending sectors and a service broken since the previous reboot.
