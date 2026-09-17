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

## Supermicro X10SRL-F motherboard standoff short

The Supermicro X10SRL-F motherboard doesn't have the standard ATX mounting hole
layout. In a case with standoffs installed for the standard layout, one standoff
has no matching hole and shorts the C1/C2 DIMM slot solder contacts on the
underside of the board. Removing that standoff fixed the issue, with no
permanent damage in our case.

When mounting a motherboard, verify that every installed case standoff aligns
with a motherboard mounting hole, and remove the unmatched ones.
