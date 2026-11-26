# Design Spec: OS Package Upgrades

## Implementation Status

| Component / Feature                    | Status                    | Details                                                                                                                                                                                                                                                                           |
| :------------------------------------- | :------------------------ | :-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Upgrade run**                        | **Fully Implemented**     | The detached `dist-upgrade` of the `update-os-packages.yaml` playbook, followed by autoremove and autoclean as steps of their own; the play can lose the job while the host finishes it, as the Linux administration notes describe.                                              |
| **Review by check run**                | **Partially Implemented** | The check run refreshes the lists and prints apt's plan and the verdict of the removal guard; it does not report the reboot-required flag. Run on the four Debian hosts (2026-11-26), on pve2 after four days off.                                                                |
| **One host at a time**                 | **Fully Implemented**     | The play is serial and leaves out the NixOS hosts by group; the Molecule job shows a failed host ending the run before the next one. On the real hosts, a check run with pve2 off ended before the next host, and one run took raspberrypi2, pve1, and hl01 in turn (2026-11-26). |
| **Removal guard**                      | **Fully Implemented**     | Reads the removals and the purges from apt's simulated plan; the Molecule job has a run where the guard fires, one where the one-host rule fires, a check run that goes on, and an approved run. On the real hosts it has only passed plans without removals (2026-11-26).        |
| **Reboot on the reboot-required flag** | **Missing**               | The reboot is a manual step after the run.                                                                                                                                                                                                                                        |
| **Downtime silences**                  | **Missing**               | Added by hand, as the monitoring guide describes.                                                                                                                                                                                                                                 |
| **Post-reboot verification**           | **Missing**               | Done by hand: the host checks on every Debian host, the guests and the pools on the Proxmox nodes.                                                                                                                                                                                |

## Goal

One run of the OS packages playbook takes a Debian host from "upgrades pending"
to "upgraded, rebooted when needed, and verified", after a human reviewed the
plan and started the run. The run covers what unattended-upgrades leaves behind
on every Debian host: the origins it does not cover (the Proxmox repository on
the nodes, with pve-manager, QEMU, the container runtime, ZFS, and the kernel)
and any upgrade that needs a removal, which it keeps back by design. The
[Ansible development guide](../guides/development/ansible.md) describes the
origins it does cover. NixOS hosts are out of scope: they upgrade through their
flake.

## Rationale

Proxmox prescribes `apt full-upgrade` and warns that `apt upgrade` can leave a
partially upgraded state, and a full upgrade may remove packages, so the
upgrades of a hypervisor stay behind a human review. The reboot a new kernel
needs takes the node's guests down, so its moment is a human decision too.
Everything else in an upgrade is mechanical.

What delays an upgrade is the cost of acting, not a missing reminder. The
`AptUpgradesPending` alert fired for pve1 on 2026-11-01 and repeated daily; the
upgrade came on 2026-11-10, with 191 packages by then. A manual upgrade is a
session of six steps that no single guide holds: refresh the lists, read the
simulated plan, add the silences, run the playbook, reboot, and verify the
guests, the pools, and the kernel. The backlog rebuilds quickly (37 packages
from the Proxmox repository on pve1 twelve days later, a kernel among them), and
a large jump carries more risk than a small one: the reboot of 2026-11-10
exposed a pool that no unit imported before the guests started.

The run therefore keeps the human for two judgments, whether the plan is safe
and whether the downtime is acceptable now, and does the rest.

### Rejected alternatives

- **Unattended full upgrades of the Proxmox origin**: removals and hypervisor
  changes that nobody reviews, which the staff position in the
  [Proxmox forum thread](https://forum.proxmox.com/threads/is-unattended-upgrade-package-safe-to-use.139808/)
  advises against. The `proxmox-ve` apt hook is no substitute for the review: it
  stops a plan that removes the `proxmox-ve` package itself or a pinned kernel,
  and lets any other removal through.
- **Units on the host that prepare the plan and apply it on a command over
  SSH**: a script, units, a timer, metrics, and alerts to maintain, where the
  playbook needs a few tasks. Their benefit is an approval given away from the
  control machine, which was not the obstacle.
- **An approval given by replying in Telegram**: a listener with the authority
  to upgrade and reboot hypervisors, driven from a chat; the bot only sends
  today.
- **A weekly digest of the pending upgrades**: with packages published this
  often it would fire every week, and it is quieter than the daily repeat the
  existing alert already has. A digest that also reports removals and a pending
  kernel needs the host to simulate the upgrade and export the result.
- **The update notification of Proxmox**: off by default on a node without a
  subscription, a second path to Telegram beside Alertmanager with no delivery
  monitoring, and it reports the Debian origins that unattended-upgrades clears
  within a day.
- **A scheduled run of the playbook from a host that is always on**: it puts the
  vault, the repository, and the lab key on that host, and still needs a way to
  approve.
- **A declared list of each node's guests**: it drifts from what runs on the
  node, and the node's own listing is what goes down with it.

## Design

### Review

A check run of the playbook with `--diff` is the review. Like the real run, it
starts by refreshing the package lists, as a step of its own, so that a host
that was off is reviewed against what the repositories hold now. It then prints
apt's simulated plan, the removals included, and the state of the host's
reboot-required flag. Apart from the lists, it changes nothing (no silence, no
reboot). A kernel in the plan means a reboot will follow the real run. The real
run refreshes the lists again, so its plan is newer than the reviewed one by the
time between the two runs; the removal guard, which simulates after that
refresh, covers what matters in that gap.

### One host at a time

The play processes its hosts one at a time, and in a real run a host that fails
stops the run for the ones after it. The two monitoring replicas are never down
together, and no guest is in the middle of an upgrade while its node reboots. A
guest and its node in the same run cost the guest two reboots. The play leaves
out the NixOS hosts of the inventory by their group, so a run never contacts
them. A host that cannot be reached stops the run like a host that fails, in a
check run as well: a run names the hosts that are on.

### Removal guard

After the refresh and before upgrading, the run simulates the upgrade without
autoremove and fails the host when that plan removes a package that
`update_os_packages_allowed_removals` does not name (a list, empty by default),
in check mode as well. A reviewed removal is approved by naming the package for
that run. Autoremove runs as a step of its own after the upgrade, outside the
guard: it takes only packages that were installed automatically and that nothing
depends on any more.

A run that names removals takes one host: it fails before the first host when
the list is not empty and the play holds more than one, since an approval given
for one host would pass unread on the others. A check run goes on to the next
host after a guard failure, so one check run reviews every host: it prints the
failure, counts it as ignored, and exits with success, since its output is the
review.

The failure names the packages that are not approved and prints the whole list
of the plan's removals as the argument that approves them. A release upgrade
goes through the same guard, with no way around it: its plan removes tens of
packages (65 on hl01's), and the printed argument is what makes naming them
practical.

### Reboot

After the upgrade, the run reboots the host when its reboot-required flag is
set, whatever set it. A second run therefore finishes a run that was interrupted
before its reboot, once apt on the host is idle (the
[Linux administration notes](../guides/operations/linux-administration.md#release-upgrade)
describe how to read a job the play lost), and a run on a host with nothing to
upgrade performs the reboot that the `RebootRequired` alert asks for. The flag
is written by the kernel hook of the `unattended-upgrades` package, which the
node role installs on every Debian host by default: a host with unattended
upgrades turned off would never reboot through this run.

### Silences

Silences are created only when a reboot follows, right before it, on a
monitoring replica that is neither the host nor one of its guests; the run fails
before the reboot when no such replica answers, so it never takes the last
replica down. They cover the host and, on a Proxmox node, the guests that the
node's own listing shows as running, with the matchers the
[monitoring guide](../guides/operations/monitoring.md#planned-downtime)
describes for planned downtime:

- A broad silence on those instances for `update_os_packages_silence_duration`
  (one hour by default), which the run expires at the end of the host's
  verification.
- A silence on the probe alerts, by their alert names, for the same duration and
  expired with the broad one. The probed services do not carry the host's name,
  so this silence is lab-wide: while it lasts, an unrelated probe failure is not
  notified.
- A silence for `UnexpectedReboot` on the same instances for 90 minutes, since
  that alert fires for an hour after the boot.
- When the host or one of its guests is a monitoring replica, a silence for
  `PrometheusNotificationsErroring`, by its alert name, for the duration of the
  reboot plus 20 minutes: the replica that stays up cannot reach the other's
  Alertmanager, and its alert looks back 15 minutes. Without it the reboot of
  pve1 notified (2026-11-26); with it the reboot of raspberrypi2 did not.

A run that dies leaves the first two silences to end on their own: for at most
their duration, a real outage of those instances, or a probe failure anywhere,
is not notified.

### Verification

After the reboot the run fails the host unless all of these hold, each check
retried until it holds or `update_os_packages_verification_wait` ends (ten
minutes by default), since the guests start in order after the boot:

- The boot time changed, and no systemd unit is in the failed state.
- On a Proxmox node, every guest that was running and every ZFS pool that was
  imported before the reboot is back, compared from the listings saved before
  it.
- No alert is suppressed by the run's silences other than `UnexpectedReboot` and
  the alerts that were already active before them, compared from the list saved
  then; the failure names the new ones.

The run reports the running kernel before and after, and fails the host when a
kernel package was among those that set the reboot-required flag and the running
kernel did not change: the flag is gone after any reboot, so nothing else
reports a host that keeps booting its old kernel, as raspberrypi2 did without
its firmware package (2026-11-26). The broad silence and the probe silence are
expired at the end of each host's verification, whether it passed or failed, so
that whatever is still broken notifies.

## Testing

The Molecule job of the playbook is its only automated test, and its instances
are containers. It covers the serial processing, the removal guard, and the
one-host rule for named removals, each guard with a case where it must fire and
a clean one. An instance cannot reboot and has no monitoring replica, so the
reboot, the silences, and the verification are exercised by runs on real hosts
only: their status rows carry that caveat until such a run has shown each of
them, and each check that can fail a host there (no replica answering, a guest
or a pool missing after the reboot, a new alert) gets a run where it must fire,
with the condition injected.

## Detection

| Failure                                   | Caught by                                                 |
| :---------------------------------------- | :-------------------------------------------------------- |
| The upgrade or a verification check fails | The run itself, which a human started and watches         |
| A run abandoned before its reboot         | `RebootRequired`, after seven days                        |
| No run at all                             | `AptUpgradesPending`, after fourteen days                 |
| A run that dies with its silences active  | Nothing: the silences end within their duration, as above |

The two alerts belong to the node health rules of the
[monitoring-alerting spec](./monitoring-alerting.md).
