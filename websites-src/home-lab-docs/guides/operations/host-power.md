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
resolves 1 W.

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

## pve2 measurements

Supermicro X10SRL-F, Xeon E5-2683 v4 (16 cores), 8 x 16 GB DDR4 RDIMM, Crucial
P310 NVMe boot, Seagate ST4000VN006 data disk, Samsung HD103SJ and OCZ Vertex 3
scratch drives, two on-board i210 NICs, OCZ ModXStream Pro 600 W PSU (2008-era
80 Plus, no PMBus). Measured on 2026-08-25 and 2026-10-04 with only the nas-pve2
guest running:

| State                             | Plug reading | pve2 share   |
| --------------------------------- | ------------ | ------------ |
| pve2 unplugged                    | 20 W         | 0 W          |
| pve2 off, plugged in              | 25 W         | 5 W          |
| pve2 on, idle                     | 67-71 W      | ~45 W        |
| pve2 booting (peak)               | ~110 W       |              |
| pve2 shutting down (peak)         | ~77 W        |              |
| RAPL package, idle                |              | 7.6 W        |
| RAPL DRAM, idle                   |              | 3.5 W        |
| Package C6 residency, cores in C6 |              | 88%, 99.8%   |
| BMC fans (mode Optimal)           |              | 300-1100 RPM |

The 5 W standby figure is the PSU standby rail plus the BMC. At 0.099 EUR/kWh,
the idle host costs about 39 EUR per year around the clock and about 4 EUR per
year while off but plugged in.

The CPU side is at its platform floor: a Broadwell-EP server platform stops at
package C6, so the remaining ~34 W of non-CPU draw is the board, the BMC, the
DIMMs, the drives, and PSU losses, and only hardware changes move it
substantially.

### Runtime experiments

| Date       | Change                                    | Before (median) | After (median) | Result                  |
| ---------- | ----------------------------------------- | --------------- | -------------- | ----------------------- |
| 2026-10-04 | PCIe ASPM policy `default` to `powersave` | 68 W, 1.6 h     | 68 W, 3.3 h    | Within noise, no errors |

The ASPM change enabled L0s and L1 on both i210 links and L1 on their root ports
(the NVMe already ran L1). The runtime write
(`echo powersave > /sys/module/pcie_aspm/parameters/policy`) does not survive a
reboot; nothing persists it yet. When a runtime change can cut remote access,
arm a self-reverting timer first (`systemd-run --on-active=20min` writing the
previous value) and cancel it only after the window is clean.
