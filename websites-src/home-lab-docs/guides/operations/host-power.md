# Host power evaluation

This guide records how we measure the power consumption of the home lab hosts
and the numbers we measured, so that a new evaluation starts from them instead
of re-measuring. The generic method (instrument choice, attribution, levers,
experiment discipline) is not repeated here; the specs todo list tracks the open
work per host under
[Host configuration](../../specs/README.md#host-configuration).

## Instrument

The studio smart plugs report power to Home Assistant, which Prometheus on
raspberrypi2 scrapes every 30 seconds (job `home_assistant`, metric
`homeassistant_sensor_power_w`). The plug that feeds pve2 is
`sensor.presa_studio_home_lab_2_power`; it also feeds other devices, so every
pve2 figure is a difference against the plug's "pve2 off" baseline. The plug
resolves 1 W. The Zigbee plugs reach Home Assistant through Zigbee2MQTT on
raspberrypi2, so the instrument is unavailable while that host is down (the
2026-10-06 stall took every plug series offline for 25 minutes).

Query it over SSH on raspberrypi2 (the Prometheus port is host-local). The
median over a window is the figure to compare; the quartiles show the noise:

```shell
P='homeassistant_sensor_power_w{entity="sensor.presa_studio_home_lab_2_power"}'
ssh pi@raspberrypi2.edge.lab.ferrari.how \
  curl -sf --get http://localhost:9090/api/v1/query \
  --data-urlencode "query=quantile_over_time(0.5, ${P}[15m])"
```

For a window in the past, append the `@ <unix timestamp>` modifier to the range
selector. To see the per-sample series around a transition (a boot, a shutdown,
a tunable change), use `query_range` with `step=30`. Prometheus retains 60 days,
so past power-on and power-off windows of a host give independent on/off pairs
without a new experiment.

Before comparing two windows, confirm that the host is idle in both (no
diagnostics running on it, same guests running) and use at least 10 minutes per
window, 20 samples. A change smaller than 1 W is within the plug's noise.

## Software readings

- CPU package and DRAM: `/sys/class/powercap/intel-rapl:0/energy_uj` and
  `intel-rapl:0:0/energy_uj`, differenced over 10 seconds.
- C-state residency and tunables: `powertop --time=20 --csv=<file>` (never
  `powertop --auto-tune`).
- BMC sensors on hosts with a BMC, in-band after the bootstrap role installed
  the IPMI tooling (`has_bmc` host flag): `ipmitool sdr type Fan`,
  `ipmitool sdr type Temperature`, `ipmitool raw 0x30 0x45 0x00` for the
  Supermicro fan mode (0 standard, 1 full, 2 optimal, 4 heavy IO), and
  `ipmitool dcmi power reading`, which reads 0 W when the PSU has no PMBus. The
  [hardware operations guide](./hardware.md) covers the BMC's LAN access and fan
  thresholds.

## pve2

Supermicro X10SRL-F (BIOS 3.4, BMC firmware 3.93), Xeon E5-2683 v4 (16 cores), 8
x 16 GB DDR4-2133 RDIMM running at 1866 MT/s, Crucial P310 NVMe boot disk,
Seagate ST4000VN006 data disk, Samsung HD103SJ and OCZ Vertex 3 scratch drives,
two on-board i210 NICs, OCZ ModXStream Pro 600 W PSU (2008-era 80 Plus, no
PMBus). The goal is to run the host 24/7 once its idle draw comes down; the
remaining steps are tracked in the
[specs todo list](../../specs/README.md#host-configuration).

### Baseline and attribution

Measured between 2026-08-25 and 2026-10-05 with only the nas-pve2 guest running:

| State                             | Plug reading | pve2 share   |
| --------------------------------- | ------------ | ------------ |
| pve2 unplugged (20-hour window)   | 20-21 W      | 0 W          |
| pve2 off, plugged in              | 25 W         | 4-5 W        |
| pve2 on, idle                     | 67-71 W      | ~45 W        |
| pve2 booting (peak)               | 110-119 W    |              |
| pve2 shutting down (peak)         | ~77 W        |              |
| RAPL package, idle                |              | 7.6 W        |
| RAPL DRAM, idle                   |              | 3.5 W        |
| Package C6 residency, cores in C6 |              | 88%, 99.8%   |
| BMC fans (mode Optimal)           |              | 300-1100 RPM |

The standby figure is the PSU standby rail plus the BMC. At 0.099 EUR/kWh, the
idle host costs about 39 EUR per year around the clock and about 4 EUR per year
while off but plugged in.

The CPU side is at its platform floor: a Broadwell-EP server platform stops at
package C6 (the BIOS limit is already C6 retention), so the remaining ~34 W of
non-CPU draw is the board, the BMC, the eight registered DIMMs, the drives, and
the PSU losses. Datasheet expectations for the drives: ~6 W for the HD103SJ, ~4
W for the ST4000VN006, ~1 W for the Vertex 3, under 1 W for the NVMe in APST.
The PSU runs at ~7% load, where a unit of that generation is expected to lose a
quarter or more of the input power; the 80 Plus figures only cover 20% load and
above.

### Levers

In order of expected gain, with status as of 2026-10-05:

| Lever                                         | Expected gain              | Status                                                                  |
| --------------------------------------------- | -------------------------- | ----------------------------------------------------------------------- |
| PSU replacement (450-550 W Platinum/Titanium) | 7-10 W, plus 1-2 W standby | Planned last, so it is measured at the final DC load                    |
| Scratch drives removal                        | ~7 W DC                    | Rejected for now: the drives stay (decision 2026-10-04)                 |
| BIOS changes (see below)                      | under 1 W (applied set)    | Applied 2026-10-06 via SUM; memory frequency deferred                   |
| SATA link power management                    | 1-3 W                      | Active since the BIOS change (kernel default `min_power_with_partial`)  |
| PCIe ASPM `powersave`                         | under 1 W                  | Measured within noise; not persisted                                    |
| PCI runtime PM `auto`                         | under 1 W                  | Measured within noise; not persisted                                    |
| BMC fan mode                                  | none                       | Already Optimal, fans at 300-1100 RPM                                   |
| CPU governor (`schedutil`)                    | under 1 W idle             | Deferred until the workload is defined; benefit is under sustained load |
| HDD spin-down                                 | excluded                   | Policy: the platters keep spinning                                      |

Realistic landing points with the scratch drives kept: 38-42 W after the BIOS
changes, 30-33 W after the PSU replacement. The runtime tunables alone do not
justify a configuration management role: their combined gain is 1-2 W, under 2
EUR per year.

### Runtime experiments

| Date       | Change                                                                                                                    | Before (median)      | After (median)             | Result                                    |
| ---------- | ------------------------------------------------------------------------------------------------------------------------- | -------------------- | -------------------------- | ----------------------------------------- |
| 2026-10-04 | PCIe ASPM policy `default` to `powersave`                                                                                 | 68 W, 1.6 h          | 68 W, 3.3 h                | Within noise, no errors                   |
| 2026-10-05 | PCIe ASPM `powersave` again after a boot                                                                                  | 69 W                 | 68-73 W (shared plug)      | Within noise, no errors                   |
| 2026-10-05 | PCI runtime PM `auto` on 99 devices                                                                                       | 69 W                 | 68 W                       | 80 devices suspended, no errors           |
| 2026-10-05 | SATA `med_power_with_dipm` on host0                                                                                       | 69 W                 | not applied                | Kernel refused: `Operation not supported` |
| 2026-10-06 | BIOS: sSATA ALPM on, hot-plug off, six-port SATA controller, audio, serial port 1 off; links now `min_power_with_partial` | 68-70 W (1 h before) | 69 W, 1 h (p25 67, p75 71) | Within noise, at most 1-2 W; no errors    |

The ASPM change enabled L0s and L1 on both i210 links and L1 on their root ports
(the NVMe already ran L1). Runtime PM suspended the uncore stubs, idle bridges,
the EHCI controllers, the management engine interfaces, and the link-down NIC;
devices wake on use. Runtime writes do not survive a reboot and nothing persists
them. When a runtime change can cut remote access, arm a self-reverting timer
first (`systemd-run --on-active=20min` writing the previous value) and cancel it
only after the window is clean; the BMC is the fallback.

The plug occasionally reports 0 W for a minute or two while the host runs
(2026-10-05, three samples), with the other plugs and the Home Assistant scrape
unaffected: a sensor artifact. Compare medians, not means or minimums.

### SATA link power management is blocked by the firmware

The kernel (6.17.2-pve) refuses any policy other than `max_performance` on all
ten ports, for two reasons verified against the kernel source at that version:

- Every port carries the firmware's hot-plug-capable bit (`ahci_port_cmd` bit 18
  set in sysfs; the boot log tags the ports `ext`). The AHCI driver treats such
  ports as external and disables link power management on them
  (`ahci_update_initial_lpm_policy` in `drivers/ata/ahci.c`), because the AHCI
  specification documents an incompatibility between link power management and
  hot-plug removal detection.
- Both controllers report the aggressive link power management capability as
  absent (`ahci_host_caps` bit 26 clear: `0xc330ff43` for the sSATA controller
  at `00:11.4`, `0xc330ff45` for the six-port controller at `00:1f.2`), which
  disables host-initiated power management. Partial and slumber are supported,
  so device-initiated management (DIPM) works once a port is no longer treated
  as external, and all three drives advertise DIPM.

The fix is in the BIOS (hot-plug off on the used ports, aggressive link power
management on). The kernel parameter `ahci.mask_port_ext=<mask>` ignores the
hot-plug bit without a BIOS change, but leaves the capability bit alone.

The BIOS change of 2026-10-06 cleared both: after the reboot the sSATA
controller reports `ahci_host_caps` `0xc730ff43` (SALP set), the three used
ports no longer carry the hot-plug bit, and the kernel applied its default
policy `min_power_with_partial` to all three links at boot, with the links up at
full speed, no errors, and the drives active (not in standby: link power
management acts on the SATA link, not on the spindle). The ZFS scrub remains the
stress test before trusting it.

### BIOS settings

The export below was taken with Supermicro Update Manager, following the
[BIOS configuration procedure](./hardware.md#bios-configuration-with-sum) in the
hardware operations guide. The changes applied on 2026-10-06 are the declared
BIOS state, committed as
[`config/bios/pve2/bios-changes.cfg`](https://github.com/ferrarimarco/home-lab/blob/master/config/bios/pve2/bios-changes.cfg);
the full export is not committed.

Power-relevant settings exported on 2026-10-05 (`*` marks the BIOS default) and
what was done with them:

| Setting                                  | Current                  | Plan                                     |
| ---------------------------------------- | ------------------------ | ---------------------------------------- |
| Power Technology                         | Energy Efficient `*`     | Keep                                     |
| Package C State Limit                    | C6 (Retention) `*`       | Keep, deepest available                  |
| Energy Performance BIAS                  | Balanced Performance `*` | Deferred with the governor               |
| ASPM Support                             | Auto (default Disabled)  | Keep                                     |
| sSATA Support Aggressive Link Power Mgmt | Disabled `*`             | Enabled (2026-10-06)                     |
| sSATA Port 0-2 Hot Plug                  | Enabled `*`              | Disabled (2026-10-06)                    |
| SATA Controller (six-port, unused)       | Enabled `*`              | Disabled (2026-10-06)                    |
| Memory Frequency                         | Auto `*` (1866 MT/s)     | Deferred until the workload is known     |
| EHCI1, EHCI2                             | Enabled `*`              | Kept: USB 2.0 ports need them            |
| Azalia                                   | Auto `*`                 | Disabled (2026-10-06)                    |
| Serial Port 1                            | Enabled `*`              | Disabled (2026-10-06); port 2 kept (SOL) |
| Restore on AC Power Loss                 | Last State `*`           | Keep for 24/7 duty                       |
