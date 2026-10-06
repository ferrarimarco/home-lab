# Hardware operations

This guide collects hardware maintenance procedures and hardware issues we
diagnosed, so we don't have to rediscover them.

## BMC management with IPMI

The `pve2` node (Supermicro X10SRL-F motherboard) has a BMC reachable at
`10.246.67.56`. Query and configure it with `ipmitool` over the LAN interface:

```shell
ipmitool -I lanplus -H 10.246.67.56 -U ADMIN sensor list
```

### Configure fan thresholds

Quiet, low-RPM fans can dip below the factory lower thresholds, triggering false
critical events and BMC fan-boost cycling. Lower the thresholds of the affected
fan sensors to stop that:

```shell
ipmitool -I lanplus -H 10.246.67.56 -U ADMIN sensor thresh FAN1 lower 150 200 250
ipmitool -I lanplus -H 10.246.67.56 -U ADMIN sensor thresh FAN2 lower 150 200 250
```

The three values after `lower` are, in order: lower non-recoverable, lower
critical, and lower non-critical.

Thresholds are stored in the BMC, so they may need re-applying after a BMC
firmware update or a BMC factory reset.

The BMC address is a DHCP lease, so it can change. The bootstrap role also
installs `ipmitool` on the host itself for hosts flagged `has_bmc` in their
host_vars: in-band commands (`ipmitool sdr type Fan`, `ipmitool sensor`) work
over SSH regardless of the BMC's address, through the `/dev/ipmi0` interface the
kernel exposes. On 2026-10-04 the fan mode read Optimal, the fans 300-1100 RPM,
and FAN1 sat below its lower non-critical threshold at 300 RPM, the symptom the
thresholds above address.

## BIOS configuration with SUM

Supermicro Update Manager (SUM) reads and writes the BIOS configuration as a
text file. On this board generation it is the only programmatic path: the BMC's
Redfish 1.0.1 service has no BIOS resource, and IPMI does not expose settings.

- The tool is proprietary and stays out of the repository: keep the downloaded
  archive outside the working tree (the control machine's downloads directory)
  and copy the extracted directory to the host only for the duration of a
  command, then remove it.
- In-band use needs no license and no driver on Linux unless Secure Boot is
  enabled (disabled on pve2). Out-of-band use through the BMC requires
  Supermicro's per-node activation key, which X10 boards do not include.
- Export the current configuration, as root on the host:

    ```shell
    ./sum -c GetCurrentBiosCfg --file pve2-bios-current.cfg --overwrite
    ```

- Apply changes from a compact file holding only the changed settings:

    ```shell
    ./sum -c ChangeBiosCfg --file pve2-bios-changes.cfg
    ```

    The uploaded configuration takes effect only after a reboot or power-up;
    `--reboot` restarts the host right away. Verify from the OS after the boot
    (SATA capability bits and port flags, memory speed, controllers present in
    `lspci`), then measure on the plug. The compact file is the declared BIOS
    state and belongs in the repository once applied (pve2's is
    [`config/bios/pve2/bios-changes.cfg`](https://github.com/ferrarimarco/home-lab/blob/master/config/bios/pve2/bios-changes.cfg));
    the full export does not. An export taken right after `ChangeBiosCfg` still
    shows the old values: the change is staged and only visible after the
    reboot.

## Supermicro X10SRL-F motherboard standoff short

The Supermicro X10SRL-F motherboard doesn't have the standard ATX mounting hole
layout. In a case with standoffs installed for the standard layout, one standoff
has no matching hole and shorts the C1/C2 DIMM slot solder contacts on the
underside of the board. Removing that standoff fixed the issue, with no
permanent damage in our case.

When mounting a motherboard, verify that every installed case standoff aligns
with a motherboard mounting hole, and remove the unmatched ones.
